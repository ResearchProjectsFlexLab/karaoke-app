//
//  MelodyPlayer.swift
//  Karaoke
//

import AVFoundation
import Foundation

/// Plays a song as simple tones. Nothing is recorded.
@MainActor
final class MelodyPlayer {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44_100
    private var isReady = false

    func play(_ song: Song) {
        stop()
        guard prepare(), let buffer = buffer(for: song) else { return }
        player.scheduleBuffer(buffer, at: nil, options: [])
        player.play()
    }

    func stop() {
        player.stop()
    }

    private func prepare() -> Bool {
        if isReady { return true }
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        guard let format else { return false }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            try engine.start()
            isReady = true
            return true
        } catch {
            return false
        }
    }

    private func buffer(for song: Song) -> AVAudioPCMBuffer? {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)
        guard let format else { return nil }
        let frameCount = AVAudioFrameCount(song.duration * sampleRate) + 1
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = frameCount

        for note in song.notes {
            let frequency = 440.0 * pow(2.0, Double(note.midi - 69) / 12.0)
            let startFrame = Int(note.start * sampleRate)
            let noteFrames = Int(note.duration * sampleRate)
            let fade = min(Int(0.02 * sampleRate), noteFrames / 4)
            for frame in 0..<noteFrames {
                let index = startFrame + frame
                guard index < Int(frameCount) else { break }
                var envelope = 1.0
                if frame < fade {
                    envelope = Double(frame) / Double(fade)
                } else if frame > noteFrames - fade {
                    envelope = Double(noteFrames - frame) / Double(fade)
                }
                let sample = sin(2.0 * .pi * frequency * Double(frame) / sampleRate)
                samples[index] += Float(sample * envelope * 0.22)
            }
        }
        return buffer
    }
}
