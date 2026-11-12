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
            board.scale = SIMD3<Float>(repeating: 2.4)
            rig.boardAnchor.addChild(board)

            // Baseline and recovery: the moonlit lake from the Follow the Snake app, under its
            // night sky, with the same gentle breathing words. The stage fades out meanwhile.
            let restScene = Entity()
            restScene.addChild(LakeScene.makeSkyDome())
            restScene.addChild(LakeScene.makeStars(count: 700, radius: 30))
            let lake = LakeScene()
            restScene.addChild(lake.root)
            restScene.components.set(OpacityComponent(opacity: 0))
            restScene.isEnabled = false
            content.add(restScene)

            let restHUD = Entity()
            restHUD.position = [0, 0.95, -2.6]
            restHUD.components.set(ViewAttachmentComponent(rootView: RestHUD(session: appModel.session)))
            restHUD.isEnabled = false
            content.add(restHUD)

            let session = appModel.session
            var time: Float = 0
            animation = content.subscribe(to: SceneEvents.Update.self) { event in
                let dt = Float(min(event.deltaTime, 0.1))
                time += Float(event.deltaTime)
                let now = Date.now
                session.refresh(at: now)
                let resting = session.isResting
                StageAnimator.fade(rig.root, toward: resting ? 0 : 1, dt: dt)
                StageAnimator.fade(restScene, toward: resting ? 1 : 0, dt: dt)
                restHUD.isEnabled = resting
                if rig.root.isEnabled { StageAnimator.step(rig, time: time, phase: session.phase) }
                if restScene.isEnabled { lake.update(session: session, now: now) }
            }
        }
    }
}

/// Per-frame motion for the stage: drifting stars, twinkling, swaying beams and a pulsing dance floor.
@MainActor
enum StageAnimator {
    /// Cross-fades the stage and the lake, as the Follow the Snake app does between its scenes.
    static func fade(_ entity: Entity, toward target: Float, dt: Float) {
        let current: Float = entity.components[OpacityComponent.self]?.opacity ?? 1
        let step: Float = dt * 1.5
        let next: Float = current < target ? min(target, current + step) : max(target, current - step)
        entity.components.set(OpacityComponent(opacity: next))
        entity.isEnabled = next > 0.001
    }

    static func step(_ rig: StageRig, time: Float, phase: KaraokeSession.Phase) {
        let isPlaying = phase == .playing
        // Keep the scene calm during baseline and recovery: no beams, no pulsing floor.
        let isResting = phase == .baseline || phase == .recovery

        rig.starField.orientation = simd_quatf(angle: time * 0.004, axis: SIMD3<Float>(0, 1, 0))

        // Twinkle a rolling subset of stars each frame.
        for (index, star) in rig.stars.enumerated() where index % 3 == 0 {
            let phase: Float = Float(index) * 1.7
            let base: Float = 0.6 + Float(index % 7) * 0.15
            let twinkle: Float = 0.7 + 0.3 * sin(time * 2.2 + phase)
            star.scale = SIMD3<Float>(repeating: base * twinkle)
        }

        let speed: Float = isPlaying ? 1.4 : 0.5
        let swing: Float = isPlaying ? 0.45 : 0.2
        for (index, beam) in rig.beams.enumerated() {
            beam.isEnabled = !isResting
            guard !isResting else { continue }
            let offset: Float = Float(index) * 1.3
            let roll: Float = sin(time * speed + offset) * swing
            let pitch: Float = -0.12 + cos(time * speed * 0.7 + offset) * swing * 0.5
            beam.orientation = simd_quatf(angle: roll, axis: SIMD3<Float>(0, 0, 1)) * simd_quatf(angle: pitch, axis: SIMD3<Float>(1, 0, 0))
        }

        let beat: Float = isPlaying ? 4 : 1.2
        for (index, tile) in rig.tiles.enumerated() {
            let wave: Float = sin(time * beat + Float(index) * 0.9)
            let lift: Float = isResting ? Float(0) : max(Float(0), wave)
            let bounce: Float = isPlaying ? lift * 0.012 : Float(0)
            tile.position.y = 0.006 + bounce
            tile.scale = SIMD3<Float>(1, 1 + lift * 2, 1)
        }
    }
}

/// Gentle breathing words for the first few breaths of each rest, then only a faint progress line.
/// Same as the Follow the Snake app.
struct RestHUD: View {
    let session: KaraokeSession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.1)) { context in
            let elapsed = session.restElapsed(at: context.date)
            let showWords = elapsed < KaraokeSession.breathCycle * 3
            VStack(spacing: 16) {
                Text(session.phase == .recovery ? "Recovery — relax and breathe" : "Baseline — relax and breathe")
                    .font(.title2)
                    .opacity(elapsed < 6 ? 0.85 : 0)
                Text(session.isInhaling(at: context.date) ? "Breathe in…" : "Breathe out…")
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .opacity(showWords ? 0.8 : 0)
                ProgressView(value: session.restProgress(at: context.date))
                    .tint(.teal)
                    .frame(width: 320)
                    .opacity(0.35)
            }
            .foregroundStyle(.white)
            .animation(.easeInOut(duration: 1.2), value: showWords)
            .animation(.easeInOut(duration: 0.8), value: session.isInhaling(at: context.date))
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
                Text("How this works")
                    .font(.system(size: 36, weight: .medium, design: .serif))
                InstructionsList(session: session)
                SetLengthPicker(session: session)
                SavedLogBadge(session: session)
            case .baseline, .recovery:
                RestPanel(session: session)
            case .readyToSing:
                ReadyToSingPanel(session: session)
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
                switch session.phase {
                case .ready, .finished:
                    Button(action: { session.start() }) {
                        Label(session.phase == .finished ? "New session" : "Start baseline", systemImage: "leaf.fill")
                            .frame(minWidth: 180)
                    }
                case .readyToSing:
                    Button(action: { session.startSinging() }) {
                        Label("Start karaoke", systemImage: "music.mic")
                            .frame(minWidth: 180)
                    }
                    Button(action: { session.stop() }) {
                        Label("End session", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                case .baseline, .playing, .recovery:
                    Button(action: { session.stop() }) {
                        Label(session.phase == .playing ? "Stop" : "End session", systemImage: "stop.fill")
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
        .frame(width: 760, height: 640)
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
