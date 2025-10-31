import Foundation

/// Represents the biometrics we monitor to craft a personalised soundscape
public struct SleepBiometrics {
    public let restingHeartRate: Int
    public let heartRateVariability: Int
    public let respiratoryRate: Double
    public let microMovementIndex: Double

    public init(
        restingHeartRate: Int,
        heartRateVariability: Int,
        respiratoryRate: Double,
        microMovementIndex: Double
    ) {
        self.restingHeartRate = restingHeartRate
        self.heartRateVariability = heartRateVariability
        self.respiratoryRate = respiratoryRate
        self.microMovementIndex = microMovementIndex
    }
}

/// Represents a single step in the progressive alarm ramp
public struct SoundscapeSegment: Identifiable {
    public let id = UUID()
    public let label: String
    public let startOffset: TimeInterval
    public let endOffset: TimeInterval
    public let soundPalette: String
    public let intensity: String
    public let coachingNote: String

    public var duration: TimeInterval { endOffset - startOffset }
}

/// A high-level description of the ambient bed we will play underneath the progressive alarm
public struct AmbientSoundProfile {
    public let name: String
    public let description: String
    public let dynamicElements: [String]
}

/// Top-level plan describing how the soundscape should unfold during the wake-up window
public struct SoundscapePlan {
    public let ambientProfile: AmbientSoundProfile
    public let segments: [SoundscapeSegment]
    public let cortisolReductionScore: Double
    public let wakeEaseRating: String
    public let recommendationSummary: String
}
