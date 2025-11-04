//
//  SleepStage.swift
//  Good-Nap
//
//  Created by AI on 11/3/25.
//

import Foundation

/// Represents different stages of sleep
public enum SleepStage: String, Codable, CaseIterable {
    case awake = "awake"
    case lightSleep = "light_sleep"
    case deepSleep = "deep_sleep"
    case remSleep = "rem_sleep"
    case unknown = "unknown"
    
    public var displayName: String {
        switch self {
        case .awake: return "Awake"
        case .lightSleep: return "Light Sleep"
        case .deepSleep: return "Deep Sleep"
        case .remSleep: return "REM Sleep"
        case .unknown: return "Unknown"
        }
    }
}

/// Represents a recorded sleep stage with metadata
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

/// Configuration for nap sessions
public struct NapConfiguration: Codable {
    public let maxDuration: TimeInterval
    public let preferredWakeTime: Date?
    public let enableSmartWake: Bool
    public let wakeWindowMinutes: Int
    public let hapticIntensity: Double
    
    public init(
        maxDuration: TimeInterval,
        preferredWakeTime: Date? = nil,
        enableSmartWake: Bool = true,
        wakeWindowMinutes: Int = 10,
        hapticIntensity: Double = 0.7
    ) {
        self.maxDuration = maxDuration
        self.preferredWakeTime = preferredWakeTime
        self.enableSmartWake = enableSmartWake
        self.wakeWindowMinutes = wakeWindowMinutes
        self.hapticIntensity = hapticIntensity
    }
}

/// Individual biometric data point
public struct BiometricDataPoint: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let heartRate: Double
    public let heartRateVariability: Double
    public let motionLevel: Double
    public let respiratoryRate: Double
    public let oxygenSaturation: Double
    
    public init(
        id: UUID = UUID(),
        timestamp: Date,
        heartRate: Double,
        heartRateVariability: Double,
        motionLevel: Double,
        respiratoryRate: Double,
        oxygenSaturation: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.heartRateVariability = heartRateVariability
        self.motionLevel = motionLevel
        self.respiratoryRate = respiratoryRate
        self.oxygenSaturation = oxygenSaturation
    }
}
