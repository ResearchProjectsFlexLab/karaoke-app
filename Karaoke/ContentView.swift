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
                case .baseline, .recovery:
                    rest
                case .readyToSing:
                    readyToSing
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
            Text("How this works")
                .font(.system(size: 34, weight: .medium, design: .serif))
            InstructionsList(session: session)
            SetLengthPicker(session: session)
            Button(action: startShow) {
                Label("Start baseline", systemImage: "leaf.fill")
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

    private var readyToSing: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            ReadyToSingPanel(session: session)
            Button(action: { session.startSinging() }) {
                Label("Start karaoke", systemImage: "music.mic")
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
            Spacer(minLength: 0)
            Button(action: { session.stop() }) {
                Label("End session", systemImage: "stop.fill")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
        }
    }

    private var rest: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 0)
            RestPanel(session: session)
            Spacer(minLength: 0)
            Button(action: { session.stop() }) {
                Label("End session", systemImage: "stop.fill")
                    .frame(minWidth: 160)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
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
                Label("New session", systemImage: "leaf.fill")
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

    /// Opens the immersive stage (if it isn't already) and starts the baseline.
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

/// The quiet baseline / recovery screen: what to do, and how long is left.
struct RestPanel: View {
    let session: KaraokeSession

    private var isBaseline: Bool { session.phase == .baseline }
    private var total: TimeInterval { isBaseline ? session.baselineDuration : session.recoveryDuration }

    var body: some View {
        VStack(spacing: 20) {
            Text(isBaseline ? "Baseline" : "Recovery")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(isBaseline ? "Sit comfortably and relax" : "Well sung. Now relax")
                .font(.system(size: 36, weight: .medium, design: .serif))
                .multilineTextAlignment(.center)
            Text(isBaseline
                 ? "Breathe normally and stay still. The songs begin when the timer ends."
                 : "Sit back, breathe normally and stay still until the timer ends.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Text(Self.clock(session.restRemaining))
                .font(.system(size: 56, weight: .light, design: .rounded).monospacedDigit())
                .contentTransition(.numericText(countsDown: true))
                .animation(.default, value: Int(session.restRemaining.rounded(.up)))
            ProgressView(value: total - session.restRemaining, total: max(total, 1))
                .frame(maxWidth: 360)
                .accessibilityLabel(isBaseline ? "Baseline progress" : "Recovery progress")
        }
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let whole = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", whole / 60, whole % 60)
    }
}

/// The three steps of a session, shown before the baseline starts.
struct InstructionsList: View {
    let session: KaraokeSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            step(1, "Baseline · 1 min", "Sit comfortably, stay still and breathe normally. No singing yet.")
            step(2, "Karaoke · \(session.length.label)", "When the baseline ends, press Start karaoke and sing along with the lyrics.")
            step(3, "Recovery · 1 min", "Starts by itself after the last song. Sit back, relax and breathe normally.")
        }
        .frame(maxWidth: 520, alignment: .leading)
    }

    private func step(_ number: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.headline.monospacedDigit())
                .frame(width: 32, height: 32)
                .background(.thinMaterial, in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Shown between the baseline and the karaoke.
struct ReadyToSingPanel: View {
    let session: KaraokeSession

    var body: some View {
        VStack(spacing: 14) {
            Label("Baseline complete", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Text("Ready to sing?")
                .font(.system(size: 36, weight: .medium, design: .serif))
            Text("\(session.song.detail). Press Start karaoke when you're ready. Recovery follows right after the last song.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
