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

enum SongBank {
    /// Public-domain lyric and melody. "Twinkle, Twinkle, Little Star"
    /// is Jane Taylor's poem "The Star" (1806), sung to the traditional tune
    /// "Ah! vous dirai-je, maman".
    static let twinkle = Song(
        id: "twinkle-twinkle",
        title: "Twinkle, Twinkle, Little Star",
        detail: "Public domain",
        lines: makeTwinkle().lines,
        notes: makeTwinkle().notes
    )

    static let all: [Song] = [twinkle]

    private static func makeTwinkle() -> (lines: [LyricLine], notes: [Note]) {
        let beat = 0.5
        let phrases: [(String, [Int])] = [
            ("Twinkle, twinkle, little star,", [60, 60, 67, 67, 69, 69, 67]),
            ("How I wonder what you are.", [65, 65, 64, 64, 62, 62, 60]),
            ("Up above the world so high,", [67, 67, 65, 65, 64, 64, 62]),
            ("Like a diamond in the sky.", [67, 67, 65, 65, 64, 64, 62]),
            ("Twinkle, twinkle, little star,", [60, 60, 67, 67, 69, 69, 67]),
            ("How I wonder what you are.", [65, 65, 64, 64, 62, 62, 60]),
        ]

        var lines: [LyricLine] = []
        var notes: [Note] = []
        var time: TimeInterval = 0

        for (index, phrase) in phrases.enumerated() {
            lines.append(LyricLine(id: index, text: phrase.0, start: time))
            for (noteIndex, midi) in phrase.1.enumerated() {
                let duration = noteIndex == phrase.1.count - 1 ? beat * 2 : beat
                notes.append(Note(midi: midi, start: time, duration: duration))
                time += duration
            }
        }

        return (lines, notes)
    }
}
