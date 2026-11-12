//
//  KaraokeSession.swift
//  Karaoke
//

import Foundation

/// One run of the study: a resting baseline, the karaoke set, then a resting recovery.
///
/// ready → baseline (1 min) → readyToSing → playing → recovery (1 min) → finished
///
/// The baseline and the karaoke each start from their own button; recovery
/// starts by itself as soon as the last song ends.
@MainActor
@Observable
final class KaraokeSession {
    enum Phase: Equatable {
        case ready
        /// Quiet rest before singing, to record a resting baseline.
        case baseline
        /// Baseline is done; waiting for the singer to press Start karaoke.
        case readyToSing
        case playing
        /// Quiet rest after singing, to let the body settle.
        case recovery
        case finished
    }

    nonisolated static let defaultRestDuration: TimeInterval = 60
    /// Normal resting breathing (12 per minute) for the paced rest scene, as in the Follow the Snake app.
    /// Not slow paced breathing, which would raise HRV and stop being a resting baseline.
    nonisolated static let inhaleSeconds: TimeInterval = 2
    nonisolated static let exhaleSeconds: TimeInterval = 3
    nonisolated static var breathCycle: TimeInterval { inhaleSeconds + exhaleSeconds }

    private(set) var song: Song
    private(set) var length: SetLength
    private(set) var phase: Phase = .ready
    /// Seconds into the set (only moves while playing).
    private(set) var elapsed: TimeInterval = 0
    /// Seconds left in the current baseline or recovery.
    private(set) var restRemaining: TimeInterval = 0
    private(set) var entries: [SessionLogEntry] = []

    let baselineDuration: TimeInterval
    let recoveryDuration: TimeInterval

    /// The log file written automatically when the last run finished or was stopped.
    private(set) var savedLogURL: URL?
    private(set) var saveError: String?

    private var songStartedAt: Date?
    private var restStartedAt: Date?
    private var playsAudio = true
    private var lastLoggedLineID: Int?
    private var lastLoggedSongTitle: String?
    /// Where this run's entries begin in `entries`.
    private var runStartIndex = 0
    private let logDirectory: URL
    private let player = MelodyPlayer()

    init(
        length: SetLength = .oneMinute,
        restDuration: TimeInterval = KaraokeSession.defaultRestDuration,
        logDirectory: URL = .documentsDirectory
    ) {
        self.length = length
        self.song = SongBank.setlist(for: length)
        self.baselineDuration = restDuration
        self.recoveryDuration = restDuration
        self.logDirectory = logDirectory
    }

    /// A session that plays exactly one song (used by tests).
    init(song: Song, restDuration: TimeInterval = KaraokeSession.defaultRestDuration, logDirectory: URL = .documentsDirectory) {
        self.length = .oneMinute
        self.song = song
        self.baselineDuration = restDuration
        self.recoveryDuration = restDuration
        self.logDirectory = logDirectory
    }

    /// True from Start until the run finishes or is stopped.
    var isActive: Bool {
        phase == .baseline || phase == .readyToSing || phase == .playing || phase == .recovery
    }

    /// Picks the set length. Ignored during a run.
    func choose(_ length: SetLength) {
        guard !isActive else { return }
        self.length = length
        song = SongBank.setlist(for: length)
        phase = .ready
    }

    /// Title of the song currently being sung within the set.
    var currentSongTitle: String {
        currentLine?.songTitle ?? song.lines.first?.songTitle ?? song.title
    }

    var currentLine: LyricLine? {
        song.line(at: elapsed)
    }

    var upcomingLine: LyricLine? {
        song.upcomingLine(after: elapsed)
    }

    func logText(generatedAt: Date = .now) -> String {
        SessionLogFormat.text(entries: entries, songTitle: song.title, generatedAt: generatedAt)
    }

    // MARK: - Running

    /// Starts a run with the baseline (or straight into the set when there is no baseline).
    /// Called by the Start baseline button.
    func start(at date: Date = .now, playsAudio: Bool = true) {
        player.stop()
        self.playsAudio = playsAudio
        elapsed = 0
        songStartedAt = nil
        lastLoggedLineID = nil
        lastLoggedSongTitle = nil
        savedLogURL = nil
        saveError = nil
        runStartIndex = entries.count
        record("session_start", at: date)
        record("set_length \(length.label), \(song.lines.count) lines, \(String(format: "%.1f", song.duration))s", at: date)

        if baselineDuration > 0 {
            beginRest(.baseline, duration: baselineDuration, at: date)
        } else {
            beginSong(at: date)
        }
    }

    func refresh(at date: Date) {
        switch phase {
        case .baseline:
            if updateRest(duration: baselineDuration, at: date) {
                record("baseline_end", at: date)
                phase = .readyToSing
                restStartedAt = nil
            }
        case .playing:
            guard let songStartedAt else { return }
            elapsed = max(0, date.timeIntervalSince(songStartedAt))
            logCurrentLine(at: date)
            if elapsed >= song.duration {
                endSong(at: date)
            }
        case .recovery:
            if updateRest(duration: recoveryDuration, at: date) {
                record("recovery_end", at: date)
                complete(at: date)
            }
        case .ready, .readyToSing, .finished:
            break
        }
    }

    /// Called by the Start karaoke button once the baseline is done.
    func startSinging(at date: Date = .now) {
        guard phase == .readyToSing else { return }
        record("karaoke_start", at: date)
        beginSong(at: date)
    }

    /// Ends the run early from any phase and saves what was recorded.
    func stop(at date: Date = .now) {
        let wasActive = isActive
        if wasActive {
            record("session_stop during \(phaseName)", at: date)
        }
        player.stop()
        phase = .ready
        songStartedAt = nil
        restStartedAt = nil
        restRemaining = 0
        elapsed = 0
        lastLoggedLineID = nil
        if wasActive {
            saveRunLog(at: date)
        }
    }

    // MARK: - Phase changes

    private func beginRest(_ restPhase: Phase, duration: TimeInterval, at date: Date) {
        phase = restPhase
        restStartedAt = date
        restRemaining = duration
        let breathing = "breathing_per_min=\(Int(60 / Self.breathCycle)) inhale_s=\(Int(Self.inhaleSeconds)) exhale_s=\(Int(Self.exhaleSeconds)) scene=moonlit_lake"
        record("\(restPhase == .baseline ? "baseline" : "recovery")_start \(Int(duration))s \(breathing)", at: date)
    }

    // MARK: - Breathing guide (baseline and recovery)

    var isResting: Bool { phase == .baseline || phase == .recovery }

    /// Seconds into the current baseline or recovery.
    func restElapsed(at now: Date = .now) -> TimeInterval {
        guard isResting, let restStartedAt else { return 0 }
        return max(0, now.timeIntervalSince(restStartedAt))
    }

    /// 0...1 through the current baseline or recovery.
    func restProgress(at now: Date = .now) -> Double {
        let total = phase == .baseline ? baselineDuration : recoveryDuration
        guard isResting, total > 0 else { return 0 }
        return min(1, restElapsed(at: now) / total)
    }

    /// Breathing guide: 0 = fully out, 1 = fully in. Eased so the motion has no sudden changes.
    func breath(at now: Date = .now) -> Float {
        let t = restElapsed(at: now).truncatingRemainder(dividingBy: Self.breathCycle)
        let x: Double = t < Self.inhaleSeconds
            ? t / Self.inhaleSeconds
            : 1 - (t - Self.inhaleSeconds) / Self.exhaleSeconds
        return Float(x * x * (3 - 2 * x))
    }

    /// True while the guide is in the breathing-in part of the cycle.
    func isInhaling(at now: Date = .now) -> Bool {
        restElapsed(at: now).truncatingRemainder(dividingBy: Self.breathCycle) < Self.inhaleSeconds
    }

    /// Returns true once the current rest period is over.
    private func updateRest(duration: TimeInterval, at date: Date) -> Bool {
        guard let restStartedAt else { return false }
        restRemaining = max(0, duration - date.timeIntervalSince(restStartedAt))
        return restRemaining <= 0
    }

    private func beginSong(at date: Date) {
        phase = .playing
        restStartedAt = nil
        restRemaining = 0
        songStartedAt = date
        elapsed = 0
        logCurrentLine(at: date)
        if playsAudio {
            player.play(song)
        }
    }

    private func endSong(at date: Date) {
        player.stop()
        songStartedAt = nil
        record("song_finished", at: date)
        if recoveryDuration > 0 {
            beginRest(.recovery, duration: recoveryDuration, at: date)
        } else {
            complete(at: date)
        }
    }

    private func complete(at date: Date) {
        phase = .finished
        restStartedAt = nil
        restRemaining = 0
        record("session_end", at: date)
        saveRunLog(at: date)
    }

    private var phaseName: String {
        switch phase {
        case .ready: "ready"
        case .baseline: "baseline"
        case .readyToSing: "waiting_to_sing"
        case .playing: "song"
        case .recovery: "recovery"
        case .finished: "finished"
        }
    }

    // MARK: - Logging

    /// Saves just this run's entries to a timestamped file.
    private func saveRunLog(at date: Date) {
        let runEntries = Array(entries[runStartIndex...])
        let text = SessionLogFormat.text(entries: runEntries, songTitle: song.title, generatedAt: date)
        do {
            savedLogURL = try SessionLogFile.save(text, at: date, in: logDirectory)
            saveError = nil
        } catch {
            savedLogURL = nil
            saveError = error.localizedDescription
        }
    }

    private func logCurrentLine(at date: Date) {
        for line in song.lines where line.start <= elapsed {
            guard lastLoggedLineID == nil || line.id > lastLoggedLineID! else { continue }
            lastLoggedLineID = line.id
            let title = line.songTitle.isEmpty ? song.title : line.songTitle
            if title != lastLoggedSongTitle {
                lastLoggedSongTitle = title
                record("song_start \(title)", at: date)
            }
            record("lyric_line \(line.id + 1) \(line.text)", at: date)
        }
    }

    private func record(_ message: String, at date: Date) {
        let line = "\(SessionLogFormat.stamp(date))  \(message)"
        entries.append(SessionLogEntry(timestamp: date, line: line))
        SessionLogger.write(line)
    }
}
