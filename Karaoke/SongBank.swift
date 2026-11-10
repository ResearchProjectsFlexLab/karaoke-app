//
//  SongBank.swift
//  Karaoke
//

import Foundation

struct Note: Equatable {
    let midi: Int
    let start: TimeInterval
    let duration: TimeInterval
}

struct LyricLine: Identifiable, Equatable {
    let id: Int
    let text: String
    let start: TimeInterval
    /// Which song in a setlist this line belongs to.
    var songTitle: String = ""
}

struct Song: Identifiable, Equatable {
    let id: String
    let title: String
    let detail: String
    let lines: [LyricLine]
    let notes: [Note]

    var duration: TimeInterval {
        notes.map { $0.start + $0.duration }.max() ?? 0
    }

    func line(at time: TimeInterval) -> LyricLine? {
        lines.last { $0.start <= time }
    }

    func upcomingLine(after time: TimeInterval) -> LyricLine? {
        guard let current = line(at: time) else { return lines.first }
        return lines.first { $0.id == current.id + 1 }
    }
}

/// How long a karaoke set should run.
enum SetLength: Int, CaseIterable, Identifiable {
    case oneMinute = 1
    case threeMinutes = 3
    case fiveMinutes = 5

    var id: Int { rawValue }
    var seconds: TimeInterval { TimeInterval(rawValue * 60) }
    var label: String { "\(rawValue) min" }
}

enum SongBank {
    /// All lyrics and melodies here are public domain.
    /// "Twinkle, Twinkle, Little Star" is Jane Taylor's poem "The Star" (1806),
    /// sung to the traditional tune "Ah! vous dirai-je, maman".
    static let twinkle = makeSong(
        id: "twinkle-twinkle",
        title: "Twinkle, Twinkle, Little Star",
        beat: 0.5,
        phrases: [
            ("Twinkle, twinkle, little star,", [60, 60, 67, 67, 69, 69, 67]),
            ("How I wonder what you are.", [65, 65, 64, 64, 62, 62, 60]),
            ("Up above the world so high,", [67, 67, 65, 65, 64, 64, 62]),
            ("Like a diamond in the sky.", [67, 67, 65, 65, 64, 64, 62]),
            ("Twinkle, twinkle, little star,", [60, 60, 67, 67, 69, 69, 67]),
            ("How I wonder what you are.", [65, 65, 64, 64, 62, 62, 60]),
        ]
    )

    /// Sarah Josepha Hale (1830), traditional tune.
    static let mary = makeSong(
        id: "mary-had-a-little-lamb",
        title: "Mary Had a Little Lamb",
        beat: 0.5,
        phrases: [
            ("Mary had a little lamb,", [64, 62, 60, 62, 64, 64, 64]),
            ("Little lamb, little lamb,", [62, 62, 62, 64, 67, 67]),
            ("Mary had a little lamb,", [64, 62, 60, 62, 64, 64, 64, 64]),
            ("Its fleece was white as snow.", [62, 62, 64, 62, 60]),
        ]
    )

    /// Traditional round, first published 1852.
    static let rowYourBoat = makeSong(
        id: "row-your-boat",
        title: "Row, Row, Row Your Boat",
        beat: 0.4,
        phrases: [
            ("Row, row, row your boat,", [60, 60, 60, 62, 64]),
            ("Gently down the stream.", [64, 62, 64, 65, 67]),
            ("Merrily, merrily, merrily, merrily,", [72, 72, 72, 67, 67, 67, 64, 64, 64, 60, 60, 60]),
            ("Life is but a dream.", [67, 65, 64, 62, 60]),
        ]
    )

    /// Traditional nursery rhyme.
    static let londonBridge = makeSong(
        id: "london-bridge",
        title: "London Bridge Is Falling Down",
        beat: 0.5,
        phrases: [
            ("London Bridge is falling down,", [67, 69, 67, 65, 64, 65, 67]),
            ("Falling down, falling down.", [62, 64, 65, 64, 65, 67]),
            ("London Bridge is falling down,", [67, 69, 67, 65, 64, 65, 67]),
            ("My fair lady.", [62, 67, 64, 60]),
        ]
    )

    static let all: [Song] = [twinkle, mary, rowYourBoat, londonBridge]

    /// Silence between songs in a set.
    static let gap: TimeInterval = 2

    /// Songs for a set of the given length, cycling through the bank in order.
    /// Whole songs only: a song is added while at least half of it fits.
    static func songs(for length: SetLength) -> [Song] {
        var picked: [Song] = []
        var total: TimeInterval = 0
        var index = 0
        while true {
            let next = all[index % all.count]
            let start = picked.isEmpty ? 0 : total + gap
            if !picked.isEmpty && start + next.duration / 2 > length.seconds { break }
            picked.append(next)
            total = start + next.duration
            index += 1
        }
        return picked
    }

    /// One continuous song made of every song in the set, so the session can play it straight through.
    static func setlist(for length: SetLength) -> Song {
        let songs = songs(for: length)
        var lines: [LyricLine] = []
        var notes: [Note] = []
        var offset: TimeInterval = 0
        for (index, song) in songs.enumerated() {
            if index > 0 { offset += gap }
            for line in song.lines {
                lines.append(LyricLine(id: lines.count, text: line.text, start: line.start + offset, songTitle: song.title))
            }
            notes += song.notes.map { Note(midi: $0.midi, start: $0.start + offset, duration: $0.duration) }
            offset += song.duration
        }
        let songWord = songs.count == 1 ? "song" : "songs"
        return Song(
            id: "set-\(length.rawValue)",
            title: "\(length.label) set",
            detail: "\(songs.count) \(songWord) · public domain",
            lines: lines,
            notes: notes
        )
    }

    private static func makeSong(id: String, title: String, beat: TimeInterval, phrases: [(String, [Int])]) -> Song {
        var lines: [LyricLine] = []
        var notes: [Note] = []
        var time: TimeInterval = 0

        for (index, phrase) in phrases.enumerated() {
            lines.append(LyricLine(id: index, text: phrase.0, start: time, songTitle: title))
            for (noteIndex, midi) in phrase.1.enumerated() {
                let duration = noteIndex == phrase.1.count - 1 ? beat * 2 : beat
                notes.append(Note(midi: midi, start: time, duration: duration))
                time += duration
            }
        }

        return Song(id: id, title: title, detail: "Public domain", lines: lines, notes: notes)
    }
}
