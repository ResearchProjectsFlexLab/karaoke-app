//
//  ImmersiveView.swift
//  Karaoke
//
//  Created by Prisha Marpu on 10/22/26.
//

import RealityKit
import SwiftUI

struct ImmersiveView: View {
    @Environment(AppModel.self) private var appModel
    @State private var animation: EventSubscription?

    var body: some View {
        RealityView { content in
            let rig = StageBuilder.make()
            content.add(rig.root)

            let board = Entity()
            board.components.set(ViewAttachmentComponent(rootView: LyricBoard(appModel: appModel)))
            board.scale = SIMD3(repeating: 2.4)
            rig.boardAnchor.addChild(board)

            let session = appModel.session
            var time: Float = 0
            animation = content.subscribe(to: SceneEvents.Update.self) { event in
                time += Float(event.deltaTime)
                session.refresh(at: .now)
                StageAnimator.step(rig, time: time, isPlaying: session.phase == .playing)
            }
        }
    }
}

/// Per-frame motion for the stage: drifting stars, twinkling, swaying beams and a pulsing dance floor.
@MainActor
enum StageAnimator {
    static func step(_ rig: StageRig, time: Float, isPlaying: Bool) {
        rig.starField.orientation = simd_quatf(angle: time * 0.004, axis: [0, 1, 0])

        // Twinkle a rolling subset of stars each frame.
        for (index, star) in rig.stars.enumerated() where index % 3 == 0 {
            let phase = Float(index) * 1.7
            let base = 0.6 + Float(index % 7) * 0.15
            star.scale = SIMD3(repeating: base * (0.7 + 0.3 * sin(time * 2.2 + phase)))
        }

        let speed: Float = isPlaying ? 1.4 : 0.5
        let swing: Float = isPlaying ? 0.45 : 0.2
        for (index, beam) in rig.beams.enumerated() {
            let offset = Float(index) * 1.3
            let roll = sin(time * speed + offset) * swing
            let pitch = -0.12 + cos(time * speed * 0.7 + offset) * swing * 0.5
            beam.orientation = simd_quatf(angle: roll, axis: [0, 0, 1]) * simd_quatf(angle: pitch, axis: [1, 0, 0])
        }

        let beat: Float = isPlaying ? 4 : 1.2
        for (index, tile) in rig.tiles.enumerated() {
            let lift = max(0, sin(time * beat + Float(index) * 0.9))
            tile.position.y = 0.006 + (isPlaying ? lift * 0.012 : 0)
            tile.scale = SIMD3(1, 1 + lift * 2, 1)
        }
    }
}

/// The big lyric screen hanging above the stage, with the start control.
struct LyricBoard: View {
    let appModel: AppModel
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    private var session: KaraokeSession { appModel.session }

    var body: some View {
        VStack(spacing: 22) {
            Text(session.phase == .playing ? session.currentSongTitle : session.song.title)
                .font(.headline)
                .foregroundStyle(.secondary)

            switch session.phase {
            case .ready:
                Text("Ready when you are")
                    .font(.system(size: 40, weight: .medium, design: .serif))
                Text("Pick a set length, then press Start.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                SetLengthPicker(session: session)
                SavedLogBadge(session: session)
            case .playing:
                Text(session.currentLine?.text ?? "")
                    .font(.system(size: 44, weight: .semibold, design: .serif))
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
                    .animation(.easeInOut(duration: 0.25), value: session.currentLine?.id)
                Text(session.upcomingLine?.text ?? " ")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                ProgressView(value: min(session.elapsed, session.song.duration), total: session.song.duration)
                    .accessibilityLabel("Song progress")
            case .finished:
                Text("That's the set")
                    .font(.system(size: 40, weight: .medium, design: .serif))
                Text("Take a bow.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                SetLengthPicker(session: session)
                SavedLogBadge(session: session)
            }

            HStack(spacing: 16) {
                if session.phase == .playing {
                    Button(action: { session.stop() }) {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(minWidth: 140)
                    }
                } else {
                    Button(action: { session.start() }) {
                        Label(session.phase == .finished ? "Sing again" : "Start", systemImage: "play.fill")
                            .frame(minWidth: 140)
                    }
                }
                Button(action: leaveStage) {
                    Label("Leave stage", systemImage: "xmark")
                }
                .buttonStyle(.bordered)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.extraLarge)
        }
        .padding(40)
        .frame(width: 720, height: 520)
        .glassBackgroundEffect()
    }

    private func leaveStage() {
        Task { @MainActor in
            appModel.immersiveSpaceState = .inTransition
            await dismissImmersiveSpace()
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
