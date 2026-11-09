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

    let song = SongBank.twinkle
    private(set) var phase: Phase = .ready
    private(set) var elapsed: TimeInterval = 0
    private(set) var entries: [SessionLogEntry] = []
    private var startedAt: Date?
    private var lastLoggedLineID: Int?
    private var didLogFinish = false
    private let player = MelodyPlayer()

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
        didLogFinish = false
        phase = .playing
        record("session_start", at: date)
        record("song_start \(song.title)", at: date)
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
    }

    private func logCurrentLine(at date: Date) {
        for line in song.lines where line.start <= elapsed {
            guard lastLoggedLineID == nil || line.id > lastLoggedLineID! else { continue }
            lastLoggedLineID = line.id
            record("lyric_line \(line.id + 1) \(line.text)", at: date)
        }
    }

    private func record(_ message: String, at date: Date) {
        let line = "\(SessionLogFormat.stamp(date))  \(message)"
        entries.append(SessionLogEntry(timestamp: date, line: line))
        SessionLogger.write(line)
    }
}
