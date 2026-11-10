//
//  KaraokeSession.swift
//  Karaoke
//

import Foundation

@MainActor
@Observable
final class KaraokeSession {
    enum Phase: Equatable {
        case ready
        case playing
        case finished
    }

    private(set) var song: Song
    private(set) var length: SetLength
    private(set) var phase: Phase = .ready
    private(set) var elapsed: TimeInterval = 0
    private(set) var entries: [SessionLogEntry] = []
    private var startedAt: Date?
    private var lastLoggedLineID: Int?
    private var didLogFinish = false
    private var lastLoggedSongTitle: String?
    private let player = MelodyPlayer()

    /// The log file written automatically when the last run finished or was stopped.
    private(set) var savedLogURL: URL?
    private(set) var saveError: String?
    /// Where the log is put in the entries list when the current run began.
    private var runStartIndex = 0
    private let logDirectory: URL

    init(length: SetLength = .oneMinute, logDirectory: URL = .documentsDirectory) {
        self.length = length
        self.song = SongBank.setlist(for: length)
        self.logDirectory = logDirectory
    }

    /// A session that plays exactly one song (used by tests).
    init(song: Song, logDirectory: URL = .documentsDirectory) {
        self.length = .oneMinute
        self.song = song
        self.logDirectory = logDirectory
    }

    /// Picks the set length. Ignored while a song is playing.
    func choose(_ length: SetLength) {
        guard phase != .playing else { return }
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

    func start(at date: Date = .now, playsAudio: Bool = true) {
        startedAt = date
        elapsed = 0
        lastLoggedLineID = nil
        lastLoggedSongTitle = nil
        didLogFinish = false
        savedLogURL = nil
        saveError = nil
        runStartIndex = entries.count
        phase = .playing
        record("session_start", at: date)
        logCurrentLine(at: date)
        if playsAudio {
            player.play(song)
        }
    }

    func refresh(at date: Date) {
        guard phase == .playing, let startedAt else { return }
        elapsed = max(0, date.timeIntervalSince(startedAt))
        logCurrentLine(at: date)
        if elapsed >= song.duration {
            finish(at: date)
        }
    }

    func stop(at date: Date = .now) {
        if phase == .playing {
            record("session_stop", at: date)
            saveRunLog(at: date)
        }
        player.stop()
        phase = .ready
        startedAt = nil
        elapsed = 0
        lastLoggedLineID = nil
    }

    private func finish(at date: Date) {
        guard !didLogFinish else { return }
        didLogFinish = true
        player.stop()
        phase = .finished
        record("song_finished", at: date)
        saveRunLog(at: date)
    }

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
