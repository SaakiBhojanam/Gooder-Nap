import Foundation
import AVFoundation
import SwiftUI

@MainActor
final class SoundscapeAudioEngine {
    static let shared = SoundscapeAudioEngine()

    private var audioPlayer: AVAudioPlayer?
    private var segmentTimers: [Timer] = []
    private var smoothingTimer: Timer?
    private var fadeOutTimer: Timer?
    private var currentVolume: Float = 0
    private var targetVolume: Float = 0
    private var isPreviewMode = false
    private var lastPlanID: UUID?

    private init() {}
    
    // These properties don't exist - remove any old properties that reference ambientNode, harmonicNode, shimmerNode, engine, reverb
    // They were part of the old AVAudioEngine implementation that was replaced with the simpler AVAudioPlayer approach

    func configurePlayback(for plan: SoundscapePlan, napDuration: TimeInterval, remainingNapTime: TimeInterval, preview: Bool) {
        guard plan.id != lastPlanID || preview != isPreviewMode else {
            return
        }

        lastPlanID = plan.id
        isPreviewMode = preview

        cancelScheduledSegments()
        configureAudioSession()
        
        // Start simple tone playback
        startSimplePlayback(preview: preview)

        targetVolume = preview ? 0.16 : 0.12
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

        // Fade out and stop audio
        let steps = 20
        var currentStep = 0
        fadeOutTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            
            MainActor.assumeIsolated {
                currentStep += 1
                let attenuation = Float(max(0, steps - currentStep)) / Float(steps)
                self.currentVolume = self.currentVolume * attenuation

                if currentStep >= steps {
                    timer.invalidate()
                    self.audioPlayer?.stop()
                    self.audioPlayer = nil
                    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                }
            }
        }

        RunLoop.main.add(fadeOutTimer!, forMode: .common)
    }

    // MARK: - Audio configuration

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true, options: [.notifyOthersOnDeactivation])
        } catch {
            print("SoundscapeAudioEngine failed to configure audio session: \(error)")
        }
    }

    private func startSimplePlayback(preview: Bool) {
        // Generate a simple harmonic tone buffer and play it
        guard let audioData = generateSimpleToneData() else {
            print("Failed to generate audio data")
            return
        }

        do {
            audioPlayer = try AVAudioPlayer(data: audioData, fileTypeHint: AVFileType.wav.rawValue)
            audioPlayer?.numberOfLoops = -1 // Loop indefinitely
            audioPlayer?.volume = 0
            audioPlayer?.play()
            print("Audio playback started successfully")
        } catch {
            print("Failed to create audio player: \(error)")
        }
    }

    private func generateSimpleToneData() -> Data? {
        // Create simple sine wave at 440 Hz (A4 note)
        let frequency: Double = 440
        let duration: Double = 2.0
        let sampleRate: Double = 44_100
        let amplitude: Float = 0.3

        let frameCount = Int(duration * sampleRate)
        var floatBuffer = [Float](repeating: 0, count: frameCount)

        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            let sine = sin(2 * .pi * frequency * time)
            floatBuffer[frame] = Float(sine) * amplitude
        }

        // Convert float buffer to WAV data
        var audioData = Data()
        
        // WAV header
        let riffHeader = "RIFF".data(using: .utf8)!
        let waveFormat = "WAVE".data(using: .utf8)!
        let fmtSubchunk = "fmt ".data(using: .utf8)!
        let dataSubchunk = "data".data(using: .utf8)!

        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate * Double(channels) * Double(bitsPerSample) / 8)
        let blockAlign: UInt16 = channels * bitsPerSample / 8
        let fmtSize: UInt32 = 16

        audioData.append(riffHeader)
        audioData.append(withUnsafeBytes(of: UInt32(36 + frameCount * 2).littleEndian) { Data($0) })
        audioData.append(waveFormat)
        audioData.append(fmtSubchunk)
        audioData.append(withUnsafeBytes(of: fmtSize.littleEndian) { Data($0) })
        audioData.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) }) // PCM format
        audioData.append(withUnsafeBytes(of: channels.littleEndian) { Data($0) })
        audioData.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        audioData.append(withUnsafeBytes(of: byteRate.littleEndian) { Data($0) })
        audioData.append(withUnsafeBytes(of: blockAlign.littleEndian) { Data($0) })
        audioData.append(withUnsafeBytes(of: bitsPerSample.littleEndian) { Data($0) })
        audioData.append(dataSubchunk)
        audioData.append(withUnsafeBytes(of: UInt32(frameCount * 2).littleEndian) { Data($0) })

        // Convert float samples to 16-bit PCM
        for sample in floatBuffer {
            let int16Sample = Int16(sample * 32767)
            audioData.append(withUnsafeBytes(of: int16Sample.littleEndian) { Data($0) })
        }

        return audioData
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

        scheduleReset(after: lastTrigger + 60)
    }

    private func scheduleSegment(_ segment: SoundscapeSegment, delay: TimeInterval, duration: TimeInterval) {
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.applySegment(segment, duration: duration)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        segmentTimers.append(timer)
    }

    private func scheduleReset(after delay: TimeInterval) {
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.targetVolume = self.isPreviewMode ? 0.12 : 0.08
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        segmentTimers.append(timer)
    }

    private func applySegment(_ segment: SoundscapeSegment, duration: TimeInterval) {
        let intensity = segment.intensity.lowercased()

        switch intensity {
        case "low":
            targetVolume = isPreviewMode ? 0.18 : 0.14
        case "medium":
            targetVolume = isPreviewMode ? 0.24 : 0.18
        case "high":
            targetVolume = isPreviewMode ? 0.3 : 0.24
        default:
            targetVolume = isPreviewMode ? 0.2 : 0.14
        }
    }

    private func cancelScheduledSegments() {
        segmentTimers.forEach { $0.invalidate() }
        segmentTimers.removeAll()
    }

    // MARK: - Volume smoothing

    private func scheduleVolumeSmoothing() {
        guard smoothingTimer == nil else { return }
        smoothingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.stepVolumesTowardTargets()
            }
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
        currentVolume = smooth(current: currentVolume, target: targetVolume)
        audioPlayer?.volume = currentVolume
    }

    private func smooth(current: Float, target: Float) -> Float {
        let delta = target - current
        let step = delta * 0.25
        if abs(step) < 0.0005 { return target }
        return current + step
    }
}
