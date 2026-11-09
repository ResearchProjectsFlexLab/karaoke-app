//
//  ContentView.swift
//  Karaoke
//
//  Created by Prisha Marpu on 10/22/26.
//

import Combine
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var session = KaraokeSession()
    @State private var exportText = ""
    @State private var isExporting = false
    @State private var exportStatus: String?

    private let clock = Timer.publish(every: 0.05, tolerance: 0.02, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                switch session.phase {
                case .ready:
                    ready
                case .playing:
                    stage
                case .finished:
                    finished
                }
            }
            .padding(32)
            .frame(maxWidth: 640, maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Karaoke")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: beginExport) {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .disabled(session.entries.isEmpty)
                }
            }
        }
        .onReceive(clock) { date in
            session.refresh(at: date)
        }
        .fileExporter(
            isPresented: $isExporting,
            document: LogFile(text: exportText),
            contentType: .plainText,
            defaultFilename: "karaoke-session"
        ) { result in
            switch result {
            case .success:
                exportStatus = "Saved."
            case .failure(let error):
                let nsError = error as NSError
                if nsError.domain == NSCocoaErrorDomain && nsError.code == CocoaError.userCancelled.rawValue {
                    exportStatus = nil
                } else {
                    exportStatus = error.localizedDescription
                }
            }
        }
    }

    private var ready: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            Text(session.song.title)
                .font(.system(size: 34, weight: .medium, design: .serif))
                .multilineTextAlignment(.center)
            Text(session.song.detail)
                .foregroundStyle(.secondary)
            Button(action: { session.start() }) {
                Label("Play", systemImage: "play.fill")
                    .frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
            exportStatusText
            Spacer(minLength: 0)
        }
    }

    private var stage: some View {
        VStack(spacing: 28) {
            Text(session.song.title)
                .font(.headline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Text(session.currentLine?.text ?? "")
                .font(.system(size: 40, weight: .medium, design: .serif))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 120)

            Text(session.upcomingLine?.text ?? " ")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)

            ProgressView(value: min(session.elapsed, session.song.duration), total: session.song.duration)
                .accessibilityLabel("Song progress")

            Button(action: { session.stop() }) {
                Label("Stop", systemImage: "stop.fill")
                    .frame(minWidth: 160)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            exportStatusText
        }
    }

    private var finished: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 0)
            Text("That's the song")
                .font(.system(size: 36, weight: .medium, design: .serif))
            Text(session.song.title)
                .foregroundStyle(.secondary)
            Button(action: { session.start() }) {
                Label("Play again", systemImage: "play.fill")
                    .frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            exportStatusText
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var exportStatusText: some View {
        if let exportStatus {
            Text(exportStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func beginExport() {
        guard !session.entries.isEmpty else { return }
        exportText = session.logText()
        isExporting = true
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
