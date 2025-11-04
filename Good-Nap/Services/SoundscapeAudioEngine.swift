import Foundation
import AVFoundation
import SwiftUI

@MainActor
final class SoundscapeAudioEngine {
    static let shared = SoundscapeAudioEngine()

    private let engine = AVAudioEngine()
    private let ambientNode = AVAudioPlayerNode()
    private let harmonicNode = AVAudioPlayerNode()
    private let shimmerNode = AVAudioPlayerNode()
    private let reverb = AVAudioUnitReverb()

    private var ambientBuffer: AVAudioPCMBuffer?
    private var harmonicBuffer: AVAudioPCMBuffer?
    private var shimmerBuffer: AVAudioPCMBuffer?

    private var segmentTimers: [Timer] = []
    private var smoothingTimer: Timer?
    private var fadeOutTimer: Timer?

    private var ambientTargetVolume: Float = 0
    private var harmonicTargetVolume: Float = 0
    private var shimmerTargetVolume: Float = 0

    private var isPreviewMode = false
    private var lastPlanID: UUID?

    private init() {
        setupEngine()
    }

    func configurePlayback(for plan: SoundscapePlan, napDuration: TimeInterval, remainingNapTime: TimeInterval, preview: Bool) {
        guard plan.id != lastPlanID || preview != isPreviewMode else {
            return
        }

        lastPlanID = plan.id
        isPreviewMode = preview

        cancelScheduledSegments()
        startEngineIfNeeded()
        configureAudioSession()
        startBaseLayersIfNeeded()

        ambientTargetVolume = preview ? 0.16 : 0.12
        harmonicTargetVolume = preview ? 0.05 : 0.0
        shimmerTargetVolume = 0.0

        scheduleVolumeSmoothing()

        if preview {
            schedulePreviewSegments(for: plan)
        } else {
            scheduleRuntimeSegments(for: plan, napDuration: napDuration, remainingNapTime: remainingNapTime)
        }
    }

    func stopPlayback() {
        lastPlanID = nil
        cancelScheduledSegments()
        stopVolumeSmoothing()
        fadeOutTimer?.invalidate()
        fadeOutTimer = nil

        guard engine.isRunning else { return }

        let steps = 20
        var currentStep = 0
        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            currentStep += 1
            let attenuation = Float(max(0, steps - currentStep)) / Float(steps)
            ambientNode.volume = ambientNode.volume * attenuation
            harmonicNode.volume = harmonicNode.volume * attenuation
            shimmerNode.volume = shimmerNode.volume * attenuation

            if currentStep >= steps {
                timer.invalidate()
                ambientNode.stop()
                harmonicNode.stop()
                shimmerNode.stop()
                engine.pause()
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        }

        RunLoop.main.add(fadeOutTimer!, forMode: .common)
    }

    // MARK: - Engine configuration

    private func setupEngine() {
        engine.attach(ambientNode)
        engine.attach(harmonicNode)
        engine.attach(shimmerNode)
        engine.attach(reverb)

        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 22

        connectNodes()
    }

    private func connectNodes() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)
        engine.connect(ambientNode, to: reverb, format: format)
        engine.connect(harmonicNode, to: reverb, format: format)
        engine.connect(shimmerNode, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            print("SoundscapeAudioEngine failed to configure audio session: \(error)")
        }
    }

    private func startEngineIfNeeded() {
        if engine.isRunning { return }
        do {
            try engine.start()
        } catch {
            print("Failed to start AVAudioEngine: \(error)")
        }
    }

    private func startBaseLayersIfNeeded() {
        if ambientBuffer == nil {
            ambientBuffer = Self.makeBrownNoiseBuffer(duration: 2.5, amplitude: 0.35)
        }

        if harmonicBuffer == nil {
            harmonicBuffer = Self.makeHarmonicBuffer(frequencies: [392, 494, 587], duration: 4.0, amplitude: 0.18)
        }

        if shimmerBuffer == nil {
            shimmerBuffer = Self.makeHarmonicBuffer(frequencies: [880, 1175], duration: 6.0, amplitude: 0.12)
        }

        if let buffer = ambientBuffer, !ambientNode.isPlaying {
            ambientNode.volume = 0
            ambientNode.scheduleBuffer(buffer, at: nil, options: [.loops])
            ambientNode.play()
        }

        if let buffer = harmonicBuffer, !harmonicNode.isPlaying {
            harmonicNode.volume = 0
            harmonicNode.scheduleBuffer(buffer, at: nil, options: [.loops])
            harmonicNode.play()
        }

        if let buffer = shimmerBuffer, !shimmerNode.isPlaying {
            shimmerNode.volume = 0
            shimmerNode.scheduleBuffer(buffer, at: nil, options: [.loops])
            shimmerNode.play()
        }
    }

    // MARK: - Segment scheduling

    private func schedulePreviewSegments(for plan: SoundscapePlan) {
        let segments = plan.segments.sorted { $0.startOffset < $1.startOffset }
        guard !segments.isEmpty else { return }

        var accumulatedDelay: TimeInterval = 0
        for segment in segments {
            let effectiveDuration = max(16, segment.duration * 0.35)
            scheduleSegment(segment, delay: accumulatedDelay, duration: effectiveDuration)
            accumulatedDelay += effectiveDuration
        }

        scheduleReset(after: accumulatedDelay + 6)
    }

    private func scheduleRuntimeSegments(for plan: SoundscapePlan, napDuration: TimeInterval, remainingNapTime: TimeInterval) {
        let segments = plan.segments.sorted { $0.startOffset < $1.startOffset }
        guard !segments.isEmpty else { return }

        let elapsed = napDuration - remainingNapTime
        var lastTrigger: TimeInterval = 0

        for segment in segments {
            let delay = max(segment.startOffset - elapsed, 0)
            let duration = max(segment.duration, 30)
            lastTrigger = max(lastTrigger, delay + duration)
            scheduleSegment(segment, delay: delay, duration: duration)
        }

        // Ensure there is a gentle ramp reset after the final segment if the nap ends without manual stop.
        scheduleReset(after: lastTrigger + 60)
    }

    private func scheduleSegment(_ segment: SoundscapeSegment, delay: TimeInterval, duration: TimeInterval) {
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            self?.applySegment(segment, duration: duration)
        }
        RunLoop.main.add(timer, forMode: .common)
        segmentTimers.append(timer)
    }

    private func scheduleReset(after delay: TimeInterval) {
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            ambientTargetVolume = isPreviewMode ? 0.12 : 0.08
            harmonicTargetVolume = isPreviewMode ? 0.02 : 0.0
            shimmerTargetVolume = 0.0
        }
        RunLoop.main.add(timer, forMode: .common)
        segmentTimers.append(timer)
    }

    private func applySegment(_ segment: SoundscapeSegment, duration: TimeInterval) {
        let intensity = segment.intensity.lowercased()

        switch intensity {
        case "low":
            ambientTargetVolume = isPreviewMode ? 0.18 : 0.14
            harmonicTargetVolume = isPreviewMode ? 0.05 : 0.02
            shimmerTargetVolume = isPreviewMode ? 0.02 : 0.0
        case "medium":
            ambientTargetVolume = isPreviewMode ? 0.24 : 0.18
            harmonicTargetVolume = isPreviewMode ? 0.08 : 0.05
            shimmerTargetVolume = isPreviewMode ? 0.04 : 0.02
        case "high":
            ambientTargetVolume = isPreviewMode ? 0.3 : 0.24
            harmonicTargetVolume = isPreviewMode ? 0.12 : 0.08
            shimmerTargetVolume = isPreviewMode ? 0.07 : 0.04
        default:
            ambientTargetVolume = isPreviewMode ? 0.2 : 0.14
            harmonicTargetVolume = isPreviewMode ? 0.06 : 0.03
            shimmerTargetVolume = isPreviewMode ? 0.03 : 0.01
        }

        // Gradually add more shimmer near the end of the segment for gentle brightness.
        let shimmerTimer = Timer.scheduledTimer(withTimeInterval: max(duration - 8, 4), repeats: false) { [weak self] _ in
            guard let self else { return }
            shimmerTargetVolume = min(shimmerTargetVolume + 0.02, 0.12)
        }
        RunLoop.main.add(shimmerTimer, forMode: .common)
        segmentTimers.append(shimmerTimer)
    }

    private func cancelScheduledSegments() {
        segmentTimers.forEach { $0.invalidate() }
        segmentTimers.removeAll()
    }

    // MARK: - Volume smoothing

    private func scheduleVolumeSmoothing() {
        guard smoothingTimer == nil else { return }
        smoothingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.stepVolumesTowardTargets()
        }
        if let smoothingTimer {
            RunLoop.main.add(smoothingTimer, forMode: .common)
        }
    }

    private func stopVolumeSmoothing() {
        smoothingTimer?.invalidate()
        smoothingTimer = nil
    }

    private func stepVolumesTowardTargets() {
        ambientNode.volume = smooth(current: ambientNode.volume, target: ambientTargetVolume)
        harmonicNode.volume = smooth(current: harmonicNode.volume, target: harmonicTargetVolume)
        shimmerNode.volume = smooth(current: shimmerNode.volume, target: shimmerTargetVolume)
    }

    private func smooth(current: Float, target: Float) -> Float {
        let delta = target - current
        let step = delta * 0.25
        if abs(step) < 0.0005 { return target }
        return current + step
    }

    // MARK: - Buffer helpers

    private static func makeBrownNoiseBuffer(duration: TimeInterval, amplitude: Float) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2) else { return nil }
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        for channel in 0..<Int(format.channelCount) {
            let channelData = buffer.floatChannelData![channel]
            var lastValue: Float = 0
            for frame in 0..<Int(frameCount) {
                let white = Float.random(in: -1...1)
                let brown = (lastValue + (0.02 * white)) / 1.02
                channelData[frame] = max(-1, min(1, brown * amplitude))
                lastValue = channelData[frame]
            }
        }

        return buffer
    }

    private static func makeHarmonicBuffer(frequencies: [Double], duration: TimeInterval, amplitude: Float) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2) else { return nil }
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        buffer.frameLength = frameCount

        let rampFrames = Int(min(4_410, frameCount / 6))

        for channel in 0..<Int(format.channelCount) {
            let channelData = buffer.floatChannelData![channel]
            for frame in 0..<Int(frameCount) {
                let time = Double(frame) / format.sampleRate
                var value: Double = 0
                for (index, frequency) in frequencies.enumerated() {
                    let phaseOffset = Double(index) * .pi / 6
                    value += sin((2 * .pi * frequency * time) + phaseOffset)
                }
                let normalized = Float(value / Double(frequencies.count))
                channelData[frame] = normalized * amplitude
            }

            // Apply gentle fade in/out to avoid pops.
            for frame in 0..<rampFrames {
                let scale = Float(frame) / Float(rampFrames)
                channelData[frame] *= scale
                channelData[Int(frameCount) - frame - 1] *= scale
            }
        }

        return buffer
    }
}
