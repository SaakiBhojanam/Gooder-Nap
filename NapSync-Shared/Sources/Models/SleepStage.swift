import Foundation

/// Represents different sleep stages detected during a nap
public enum SleepStage: String, CaseIterable, Codable {
    case awake = "awake"
    case lightSleep = "light_sleep"
    case deepSleep = "deep_sleep"
    case remSleep = "rem_sleep"
    case unknown = "unknown"
    
    public var description: String {
        switch self {
        case .awake:
            return "Awake"
        case .lightSleep:
            return "Light Sleep"
        case .deepSleep:
            return "Deep Sleep"
        case .remSleep:
            return "REM Sleep"
        case .unknown:
            return "Unknown"
        }
    }
    
    /// Whether this stage is optimal for waking up
    public var isOptimalForWaking: Bool {
        return self == .lightSleep || self == .awake
    }
}

/// A timestamped record of a detected sleep stage
public struct SleepStageRecord: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let stage: SleepStage
    public let confidence: Double // 0.0 to 1.0
    public let duration: TimeInterval
    
    public init(
        id: UUID = UUID(),
        timestamp: Date,
        stage: SleepStage,
        confidence: Double,
        duration: TimeInterval
    ) {
        self.id = id
        self.timestamp = timestamp
        self.stage = stage
        self.confidence = confidence
        self.duration = duration
    }
}
