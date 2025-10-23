import Foundation

/// Represents a single biometric data point during nap monitoring
public struct BiometricDataPoint: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let heartRate: Double
    public let heartRateVariability: Double
    public let motionLevel: Double
    public let respiratoryRate: Double?
    public let oxygenSaturation: Double?
    
    public init(
        id: UUID = UUID(),
        timestamp: Date,
        heartRate: Double,
        heartRateVariability: Double,
        motionLevel: Double,
        respiratoryRate: Double? = nil,
        oxygenSaturation: Double? = nil
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

/// Configuration settings for a nap session
public struct NapConfiguration: Codable {
    public let maxDuration: TimeInterval
    public let preferredWakeTime: Date?
    public let enableSmartWake: Bool
    public let wakeWindowMinutes: Int
    public let hapticIntensity: Double
    
    public init(
        maxDuration: TimeInterval = 30 * 60, // 30 minutes default
        preferredWakeTime: Date? = nil,
        enableSmartWake: Bool = true,
        wakeWindowMinutes: Int = 10,
        hapticIntensity: Double = 0.8
    ) {
        self.maxDuration = maxDuration
        self.preferredWakeTime = preferredWakeTime
        self.enableSmartWake = enableSmartWake
        self.wakeWindowMinutes = wakeWindowMinutes
        self.hapticIntensity = hapticIntensity
    }
}