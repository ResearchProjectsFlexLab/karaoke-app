//
//  KaraokeTests.swift
//  KaraokeTests
//
//  Created by Prisha Marpu on 10/22/26.
//

import Foundation
import Testing
@testable import Karaoke

struct KaraokeTests {

    @Test func songBankHasThePublicDomainSongs() {
        #expect(SongBank.all.map(\.title) == [
            "Twinkle, Twinkle, Little Star",
            "Mary Had a Little Lamb",
            "Row, Row, Row Your Boat",
            "London Bridge Is Falling Down",
        ])
        #expect(SongBank.all.contains { $0.title.lowercased().contains("baby") } == false)
    }

    @Test(arguments: SetLength.allCases)
    func setlistRoughlyMatchesTheChosenLength(length: SetLength) {
        let set = SongBank.setlist(for: length)
        #expect(abs(set.duration - length.seconds) <= 15)
        #expect(set.lines.first?.songTitle == "Twinkle, Twinkle, Little Star")
        #expect(set.lines.map(\.id) == Array(0..<set.lines.count))
        #expect(SongBank.songs(for: length).count >= 2)
    }

    @Test func longerSetsHaveMoreSongs() {
        let counts = SetLength.allCases.map { SongBank.songs(for: $0).count }
        #expect(counts == counts.sorted())
        #expect(counts[0] < counts[2])
    }

    @Test @MainActor func setLogsEachSongAsItStarts() {
        let session = KaraokeSession(length: .oneMinute, restDuration: 0, logDirectory: tempLogs())
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        session.start(at: start, playsAudio: false)
        session.refresh(at: start.addingTimeInterval(session.song.duration + 1))

        let songStarts = session.entries.filter { $0.line.contains("song_start") }
        #expect(songStarts.count == SongBank.songs(for: .oneMinute).count)
        #expect(songStarts[1].line.contains("song_start Mary Had a Little Lamb"))
        #expect(session.phase == .finished)
    }

    @Test @MainActor func choosingALengthRebuildsTheSet() {
        let session = KaraokeSession(logDirectory: tempLogs())
        session.choose(.fiveMinutes)
        #expect(session.length == .fiveMinutes)
        #expect(session.song.title == "5 min set")
    }

    @Test func twinkleHasSixLyricLines() {
        let song = SongBank.twinkle
        #expect(song.lines.map(\.text) == [
            "Twinkle, twinkle, little star,",
            "How I wonder what you are.",
            "Up above the world so high,",
            "Like a diamond in the sky.",
            "Twinkle, twinkle, little star,",
            "How I wonder what you are.",
        ])
    }

    @Test func lyricsAdvanceWithTheMelody() {
        let song = SongBank.twinkle
        #expect(song.line(at: 0)?.text == "Twinkle, twinkle, little star,")
        #expect(song.line(at: 3.9)?.text == "Twinkle, twinkle, little star,")
        #expect(song.line(at: 4)?.text == "How I wonder what you are.")
        #expect(song.upcomingLine(after: 0)?.text == "How I wonder what you are.")
        #expect(song.duration == 24)
        #expect(song.line(at: 23.9)?.text == "How I wonder what you are.")
    }

    @Test @MainActor func startingLogsTheSongAndFirstLine() {
        let session = KaraokeSession(song: SongBank.twinkle, restDuration: 0, logDirectory: tempLogs())
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        session.start(at: start, playsAudio: false)

        #expect(session.entries.count == 4)
        #expect(session.entries[0].line.contains("session_start"))
        #expect(session.entries[1].line.contains("set_length"))
        #expect(session.entries[2].line.contains("song_start Twinkle, Twinkle, Little Star"))
        #expect(session.entries[3].line.contains("lyric_line 1 Twinkle, twinkle, little star,"))
        #expect(session.entries[0].line.hasPrefix("\(SessionLogFormat.stamp(start))  "))
    }

    @Test @MainActor func eachNewLyricIsLoggedOnce() {
        let session = KaraokeSession(song: SongBank.twinkle, restDuration: 0, logDirectory: tempLogs())
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        session.start(at: start, playsAudio: false)

        session.refresh(at: start.addingTimeInterval(4))
        session.refresh(at: start.addingTimeInterval(4.2))

        let lyricLines = session.entries.filter { $0.line.contains("lyric_line") }
        #expect(lyricLines.count == 2)
        #expect(lyricLines[1].line.contains("lyric_line 2 How I wonder what you are."))
    }

    @Test @MainActor func finishingLogsTheEndOfTheSong() {
        let session = KaraokeSession(song: SongBank.twinkle, restDuration: 0, logDirectory: tempLogs())
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        session.start(at: start, playsAudio: false)

        session.refresh(at: start.addingTimeInterval(24))
        session.refresh(at: start.addingTimeInterval(25))

        #expect(session.phase == .finished)
        #expect(session.entries.contains { $0.line.contains("song_finished") })
        #expect(session.entries.filter { $0.line.contains("song_finished") }.count == 1)
        #expect(session.entries.filter { $0.line.contains("lyric_line") }.count == 6)
    }

    @Test @MainActor func stoppingEarlyLogsSessionStop() {
        let session = KaraokeSession(song: SongBank.twinkle, restDuration: 0, logDirectory: tempLogs())
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        session.start(at: start, playsAudio: false)
        session.stop(at: start.addingTimeInterval(2))

        #expect(session.phase == .ready)
        #expect(session.entries.last?.line.contains("session_stop") == true)
        #expect(session.entries.contains { $0.line.contains("song_finished") } == false)
    }

    @Test @MainActor func savedLogContainsTheSession() {
        let session = KaraokeSession(song: SongBank.twinkle, restDuration: 0, logDirectory: tempLogs())
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        session.start(at: start, playsAudio: false)
        session.refresh(at: start.addingTimeInterval(24))

        let generated = Date(timeIntervalSince1970: 1_700_000_100)
        let text = session.logText(generatedAt: generated)

        #expect(text.hasPrefix("Karaoke\nGenerated:"))
        #expect(text.contains("song_start Twinkle, Twinkle, Little Star"))
        #expect(text.contains("Entries: \(session.entries.count)"))
        #expect(text.contains("session_start"))
        #expect(text.contains("song_start"))
        #expect(text.contains("lyric_line 1"))
        #expect(text.contains("lyric_line 6"))
        #expect(text.contains("song_finished"))
        #expect(text.contains(SessionLogFormat.stamp(generated)))
    }

    @Test @MainActor func finishingSavesATimestampedLogFile() throws {
        let folder = tempLogs()
        let session = KaraokeSession(song: SongBank.twinkle, restDuration: 0, logDirectory: folder)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        session.start(at: start, playsAudio: false)
        #expect(session.savedLogURL == nil)

        let end = start.addingTimeInterval(25)
        session.refresh(at: end)

        let url = try #require(session.savedLogURL)
        #expect(url.lastPathComponent == SessionLogFile.fileName(for: end))
        #expect(url.lastPathComponent.hasPrefix("karaoke-log_"))
        #expect(url.pathExtension == "txt")
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("session_start"))
        #expect(text.contains("lyric_line 6"))
        #expect(text.contains("song_finished"))
    }

    @Test @MainActor func stoppingEarlySavesOnlyThatRun() throws {
        let session = KaraokeSession(song: SongBank.twinkle, restDuration: 0, logDirectory: tempLogs())
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        session.start(at: start, playsAudio: false)
        session.refresh(at: start.addingTimeInterval(25))

        let second = start.addingTimeInterval(60)
        session.start(at: second, playsAudio: false)
        #expect(session.savedLogURL == nil)
        session.stop(at: second.addingTimeInterval(3))

        let url = try #require(session.savedLogURL)
        let text = try String(contentsOf: url, encoding: .utf8)
        #expect(text.contains("session_stop"))
        #expect(text.contains("song_finished") == false)
        #expect(text.components(separatedBy: "session_start").count == 2)
    }

    @Test func logFileNameUsesDateAndTime() {
        var parts = DateComponents()
        (parts.year, parts.month, parts.day, parts.hour, parts.minute, parts.second) = (2026, 11, 7, 16, 56, 35)
        let date = Calendar.current.date(from: parts)!
        #expect(SessionLogFile.fileName(for: date) == "karaoke-log_2026-11-07_16-56-35.txt")
    }

    // MARK: - Baseline and recovery

    @Test @MainActor func runGoesBaselineThenSongsThenRecovery() throws {
        let session = KaraokeSession(song: SongBank.twinkle, logDirectory: tempLogs())
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        session.start(at: start, playsAudio: false)

        #expect(session.baselineDuration == 60)
        #expect(session.phase == .baseline)
        #expect(session.entries.contains { $0.line.contains("lyric_line") } == false)

        session.refresh(at: start.addingTimeInterval(30))
        #expect(session.phase == .baseline)
        #expect(session.restRemaining == 30)

        // Baseline ends, but karaoke waits for its own button.
        session.refresh(at: start.addingTimeInterval(60))
        #expect(session.phase == .readyToSing)
        session.refresh(at: start.addingTimeInterval(75))
        #expect(session.phase == .readyToSing)
        #expect(session.entries.contains { $0.line.contains("song_start") } == false)

        let sing = start.addingTimeInterval(80)
        session.startSinging(at: sing)
        #expect(session.phase == .playing)
        #expect(session.currentLine?.text == "Twinkle, twinkle, little star,")

        session.refresh(at: sing.addingTimeInterval(25))
        #expect(session.phase == .recovery)
        #expect(session.savedLogURL == nil)

        session.refresh(at: sing.addingTimeInterval(25 + 59))
        #expect(session.phase == .recovery)

        session.refresh(at: sing.addingTimeInterval(25 + 61))
        #expect(session.phase == .finished)

        let order = ["session_start", "baseline_start 60s", "baseline_end", "karaoke_start", "song_start",
                     "song_finished", "recovery_start 60s", "recovery_end", "session_end"]
        let positions = try order.map { event in
            try #require(session.entries.firstIndex { $0.line.contains(event) }, "missing \(event)")
        }
        #expect(positions == positions.sorted())

        let text = try String(contentsOf: try #require(session.savedLogURL), encoding: .utf8)
        for event in order { #expect(text.contains(event)) }
    }

    @Test @MainActor func stoppingDuringBaselineSavesTheLog() throws {
        let session = KaraokeSession(song: SongBank.twinkle, logDirectory: tempLogs())
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        session.start(at: start, playsAudio: false)
        session.stop(at: start.addingTimeInterval(10))

        #expect(session.phase == .ready)
        let text = try String(contentsOf: try #require(session.savedLogURL), encoding: .utf8)
        #expect(text.contains("session_stop during baseline"))
        #expect(text.contains("song_start") == false)
    }

    @Test @MainActor func setLengthCannotChangeDuringARun() {
        let session = KaraokeSession(logDirectory: tempLogs())
        session.start(at: .now, playsAudio: false)
        session.choose(.fiveMinutes)
        #expect(session.length == .oneMinute)
        #expect(session.isActive)
    }

    @Test @MainActor func startKaraokeOnlyWorksAfterTheBaseline() {
        let session = KaraokeSession(song: SongBank.twinkle, logDirectory: tempLogs())
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        session.start(at: start, playsAudio: false)
        session.startSinging(at: start.addingTimeInterval(5))
        #expect(session.phase == .baseline)
        #expect(session.entries.contains { $0.line.contains("karaoke_start") } == false)
    }

    @Test @MainActor func stoppingWhileWaitingToSingSavesTheLog() throws {
        let session = KaraokeSession(song: SongBank.twinkle, logDirectory: tempLogs())
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        session.start(at: start, playsAudio: false)
        session.refresh(at: start.addingTimeInterval(61))
        session.stop(at: start.addingTimeInterval(70))
        let text = try String(contentsOf: try #require(session.savedLogURL), encoding: .utf8)
        #expect(text.contains("baseline_end"))
        #expect(text.contains("session_stop during waiting_to_sing"))
    }

    @Test func restClockRoundsUp() {
        #expect(RestPanel.clock(60) == "1:00")
        #expect(RestPanel.clock(59.2) == "1:00")
        #expect(RestPanel.clock(42.5) == "0:43")
        #expect(RestPanel.clock(0) == "0:00")
    }
}


private func tempLogs() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("karaoke-tests-\(UUID().uuidString)")
}
