import Foundation
import Combine

/// Generates a progressive soundscape plan that mimics an ML-powered system.
/// The logic is intentionally deterministic to keep the demo predictable, but
/// the heuristics are structured as if they were driven by a trained model.
public final class SoundscapeService: ObservableObject {
    public static let shared = SoundscapeService()

    @Published public private(set) var latestPlan: SoundscapePlan?

    private init() {}

    /// Generates a mock ML output describing the optimal soundscape to ease the user awake.
    /// - Parameters:
    ///   - napDuration: Planned nap duration in seconds.
    ///   - biometrics: Current biometric snapshot captured from HealthKit.
    /// - Returns: A detailed soundscape plan.
    public func generatePlan(napDuration: TimeInterval, biometrics: SleepBiometrics) -> SoundscapePlan {
        let normalizedStress = clamp(Double(biometrics.restingHeartRate) / 70.0, lower: 0.8, upper: 1.4)
        let calmnessFactor = clamp(Double(biometrics.heartRateVariability) / 55.0, lower: 0.6, upper: 1.3)
        let motionScore = clamp(1.0 - biometrics.microMovementIndex, lower: 0.3, upper: 1.2)

        let cortisolScore = clamp((1.6 - (normalizedStress * 0.6 + calmnessFactor * 0.3 + motionScore * 0.1)) * 38, lower: 48, upper: 92)
        let wakeEaseRating = cortisolScore > 80 ? "Featherlight" : (cortisolScore > 65 ? "Balanced" : "Supported")

        let ambientProfile = selectAmbientProfile(for: biometrics, napDuration: napDuration)
        let segments = buildSegments(napDuration: napDuration, biometrics: biometrics, wakeEase: wakeEaseRating)

        let plan = SoundscapePlan(
            ambientProfile: ambientProfile,
            segments: segments,
            cortisolReductionScore: cortisolScore,
            wakeEaseRating: wakeEaseRating,
            recommendationSummary: recommendationText(for: cortisolScore, profile: ambientProfile)
        )

        latestPlan = plan
        return plan
    }

    private func buildSegments(
        napDuration: TimeInterval,
        biometrics: SleepBiometrics,
        wakeEase: String
    ) -> [SoundscapeSegment] {
        let wakeWindow = clamp(napDuration * 0.25, lower: 8 * 60, upper: 18 * 60)
        let startOfWindow = max(60, napDuration - wakeWindow)
        let segmentDuration = wakeWindow / 3

        let breathingCue = biometrics.respiratoryRate < 13 ? "slow tidal breaths" : "steady ocean swell"
        let microMotionCue = biometrics.microMovementIndex < 0.2 ? "micro-chimes" : "gentle pulses"

        let segmentOne = SoundscapeSegment(
            label: "Prime",
            startOffset: startOfWindow,
            endOffset: startOfWindow + segmentDuration,
            soundPalette: "theta-wave pads + \(breathingCue)",
            intensity: "Feather soft",
            coachingNote: "Elevates parasympathetic tone with low frequency pads and \(breathingCue)."
        )

        let segmentTwo = SoundscapeSegment(
            label: "Ascend",
            startOffset: startOfWindow + segmentDuration,
            endOffset: startOfWindow + segmentDuration * 2,
            soundPalette: "aurora bells + \(microMotionCue)",
            intensity: wakeEase == "Featherlight" ? "Soft shimmer" : "Measured glow",
            coachingNote: "Introduces melodic cues aligned with your current HRV to keep cortisol muted."
        )

        let segmentThree = SoundscapeSegment(
            label: "Awaken",
            startOffset: napDuration - segmentDuration,
            endOffset: napDuration,
            soundPalette: "bright piano harmonics + coastal dawn", 
            intensity: wakeEase == "Supported" ? "Guided rise" : "Radiant drift",
            coachingNote: "Final uplift timed with your light sleep window to minimise grogginess."
        )

        return [segmentOne, segmentTwo, segmentThree]
    }

    private func selectAmbientProfile(for biometrics: SleepBiometrics, napDuration: TimeInterval) -> AmbientSoundProfile {
        if biometrics.heartRateVariability > 60 && biometrics.microMovementIndex < 0.2 {
            return AmbientSoundProfile(
                name: "Glacier Stillness",
                description: "A crystalline drone with sparse winds tailored for your calm nervous system.",
                dynamicElements: ["distant choirs", "sub-bass tides", "glassy harmonics"]
            )
        } else if biometrics.restingHeartRate > 64 || napDuration < 45 * 60 {
            return AmbientSoundProfile(
                name: "Forest Canopy",
                description: "Layered foliage, cicadas, and warm woodwinds help smooth elevated heart rhythms.",
                dynamicElements: ["midnight crickets", "wind through leaves", "soft marimba pulses"]
            )
        } else {
            return AmbientSoundProfile(
                name: "Lunar Coast",
                description: "Gentle shoreline swells blended with low-tempo synth swells to stabilise HRV.",
                dynamicElements: ["rolling surf", "calm seaglass chimes", "slow synth bloom"]
            )
        }
    }

    private func recommendationText(for score: Double, profile: AmbientSoundProfile) -> String {
        switch score {
        case 85...:
            return "Your nervous system is primed. The \(profile.name) bed keeps cortisol drift minimal while you surface."
        case 70..<85:
            return "We’ll lean on \(profile.dynamicElements.first ?? "gentle textures") to release residual stress hormones."
        default:
            return "Expect a guided lift – \(profile.description) keeps your wake-up kind even with moderate stress markers."
        }
    }

    private func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        return min(max(value, lower), upper)
    }
}
