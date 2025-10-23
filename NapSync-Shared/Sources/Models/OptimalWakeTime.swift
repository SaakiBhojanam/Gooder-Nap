import Foundation

/// Represents an optimal time for waking up during a nap
public struct OptimalWakeTime: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let confidence: Double
    public let sleepStage: SleepStage
    public let reason: WakeReason
    
    public init(
        id: UUID = UUID(),
        timestamp: Date,
        confidence: Double,
        sleepStage: SleepStage,
        reason: WakeReason
    ) {
        self.id = id
        self.timestamp = timestamp
        self.confidence = confidence
        self.sleepStage = sleepStage
        self.reason = reason
    }
}

/// Reasons for recommending a wake time
public enum WakeReason: String, CaseIterable, Codable {
    case lightSleepDetected = "light_sleep_detected"
    case motionIncrease = "motion_increase"
    case heartRateChange = "heart_rate_change"
    case targetTimeReached = "target_time_reached"
    case userRequest = "user_request"
    
    public var description: String {
        switch self {
        case .lightSleepDetected:
            return "Light sleep phase detected"
        case .motionIncrease:
            return "Increased movement detected"
        case .heartRateChange:
            return "Heart rate pattern change"
        case .targetTimeReached:
            return "Target nap duration reached"
        case .userRequest:
            return "Manual wake request"
        }
    }
}