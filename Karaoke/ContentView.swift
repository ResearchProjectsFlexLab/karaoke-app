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
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @State private var exportText = ""
    @State private var isExporting = false
    @State private var exportStatus: String?

    private var session: KaraokeSession { appModel.session }

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
                ToolbarItem(placement: .topBarLeading) {
                    ToggleImmersiveSpaceButton()
                }
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
            Text("How long do you want to sing?")
                .font(.system(size: 34, weight: .medium, design: .serif))
                .multilineTextAlignment(.center)
            SetLengthPicker(session: session)
            Text(session.song.detail)
                .foregroundStyle(.secondary)
            Button(action: startShow) {
                Label("Start", systemImage: "play.fill")
                    .frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
            SavedLogBadge(session: session)
            exportStatusText
            Spacer(minLength: 0)
        }
    }

    private var stage: some View {
        VStack(spacing: 28) {
            Text(session.currentSongTitle)
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
            Text("That's the set")
                .font(.system(size: 36, weight: .medium, design: .serif))
            Text("Sing again?")
                .foregroundStyle(.secondary)
            SetLengthPicker(session: session)
            Button(action: startShow) {
                Label("Play again", systemImage: "play.fill")
                    .frame(minWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            SavedLogBadge(session: session)
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

    /// Opens the immersive stage (if it isn't already) and starts the song.
    private func startShow() {
        Task { @MainActor in
            if appModel.immersiveSpaceState == .closed {
                appModel.immersiveSpaceState = .inTransition
                switch await openImmersiveSpace(id: appModel.immersiveSpaceID) {
                case .opened:
                    break
                case .userCancelled, .error:
                    appModel.immersiveSpaceState = .closed
                @unknown default:
                    appModel.immersiveSpaceState = .closed
                }
            }
            session.start()
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

/// Lets the singer pick a 1, 3 or 5 minute set before starting.
struct SetLengthPicker: View {
    let session: KaraokeSession

    var body: some View {
        Picker("Set length", selection: Binding(get: { session.length }, set: { session.choose($0) })) {
            ForEach(SetLength.allCases) { length in
                Text(length.label).tag(length)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 320)
    }
}

/// Confirms where the run's log was saved automatically.
struct SavedLogBadge: View {
    let session: KaraokeSession

    var body: some View {
        if let url = session.savedLogURL {
            VStack(spacing: 4) {
                Label("Log saved", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.green)
                Text(SessionLogFile.filesLocation)
                    .font(.caption)
                Text(url.lastPathComponent)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
        } else if let error = session.saveError {
            Label("Couldn't save log: \(error)", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}
