import Foundation

/// Represents a complete nap session with all associated data
public struct NapSession: Codable, Identifiable {
    public let id: UUID
    public let startTime: Date
    public let targetDuration: TimeInterval
    public let actualEndTime: Date?
    public let targetEndTime: Date
    public let optimalWakeTime: Date?
    public let sleepStages: [SleepStageRecord]
    public let biometricData: [BiometricDataPoint]
    public let configuration: NapConfiguration
    public let wasOptimalWakeUsed: Bool
    
    public init(
        id: UUID = UUID(),
        startTime: Date,
        targetDuration: TimeInterval,
        configuration: NapConfiguration
    ) {
        self.id = id
        self.startTime = startTime
        self.targetDuration = targetDuration
        self.targetEndTime = startTime.addingTimeInterval(targetDuration)
        self.actualEndTime = nil
        self.optimalWakeTime = nil
        self.sleepStages = []
        self.biometricData = []
        self.configuration = configuration
        self.wasOptimalWakeUsed = false
    }
    
    public var duration: TimeInterval {
        if let endTime = actualEndTime {
            return endTime.timeIntervalSince(startTime)
        }
        return Date().timeIntervalSince(startTime)
    }
    
    public var isActive: Bool {
        return actualEndTime == nil
    }
    
    public var timeRemaining: TimeInterval {
        guard isActive else { return 0 }
        return max(0, targetEndTime.timeIntervalSince(Date()))
    }
}