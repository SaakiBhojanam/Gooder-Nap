import Foundation

/// Represents a complete nap session with all associated data
public struct NapSession: Codable, Identifiable {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date?
    public let configuration: NapConfiguration
    public let biometricData: [BiometricDataPoint]
    public let sleepStages: [SleepStageRecord]
    public let optimalWakeTime: Date?
    public let actualWakeTime: Date?
    public let userRating: Int? // 1-5 scale
    public let notes: String?
    
    public var duration: TimeInterval? {
        guard let endTime = endTime else { return nil }
        return endTime.timeIntervalSince(startTime)
    }
    
    public var averageHeartRate: Double? {
        guard !biometricData.isEmpty else { return nil }
        return biometricData.map { $0.heartRate }.reduce(0, +) / Double(biometricData.count)
    }
    
    public var averageHRV: Double? {
        guard !biometricData.isEmpty else { return nil }
        return biometricData.map { $0.heartRateVariability }.reduce(0, +) / Double(biometricData.count)
    }
    
    public init(
        id: UUID = UUID(),
        startTime: Date,
        endTime: Date? = nil,
        configuration: NapConfiguration,
        biometricData: [BiometricDataPoint] = [],
        sleepStages: [SleepStageRecord] = [],
        optimalWakeTime: Date? = nil,
        actualWakeTime: Date? = nil,
        userRating: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.configuration = configuration
        self.biometricData = biometricData
        self.sleepStages = sleepStages
        self.optimalWakeTime = optimalWakeTime
        self.actualWakeTime = actualWakeTime
        self.userRating = userRating
        self.notes = notes
    }
}