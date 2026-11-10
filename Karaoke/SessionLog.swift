//
//  SessionLog.swift
//  Karaoke
//

import Foundation
import os
import SwiftUI
import UniformTypeIdentifiers

struct SessionLogEntry: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let line: String
}

enum SessionLogFormat {
    static func text(entries: [SessionLogEntry], songTitle _: String, generatedAt: Date) -> String {
        var lines = [
            "Karaoke",
            "Generated: \(stamp(generatedAt))",
            "Entries: \(entries.count)",
            "",
        ]
        lines.append(contentsOf: entries.map(\.line))
        return lines.joined(separator: "\n") + "\n"
    }

    static func stamp(_ date: Date) -> String { clock.string(from: date) }

    private static let clock: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}

/// Writes each finished or stopped run to the app's Documents folder,
/// which the Files app shows under On My Apple Vision Pro › Karaoke.
enum SessionLogFile {
    static let filesLocation = "Files › On My Apple Vision Pro › Karaoke"

    static func fileName(for date: Date) -> String {
        "karaoke-log_\(fileStamp.string(from: date)).txt"
    }

    @discardableResult
    static func save(_ text: String, at date: Date, in directory: URL = .documentsDirectory) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(fileName(for: date))
        try Data(text.utf8).write(to: url, options: .atomic)
        return url
    }

    private static let fileStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}

enum SessionLogger {
    private static let logger = Logger(subsystem: "FlexLab.Karaoke", category: "SessionLog")

    static func write(_ line: String) {
        logger.info("\(line, privacy: .public)")
    }
}

nonisolated struct LogFile: FileDocument {
    static var readableContentTypes: [UTType] { [.plainText] }

    var text: String

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}
