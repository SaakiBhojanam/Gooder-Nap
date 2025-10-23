import Foundation

/// Represents biometric data collected from the Apple Watch
public struct BiometricDataPoint: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let heartRate: Double?
    public let heartRateVariability: Double?
    public let motionMagnitude: Double?
    public let motionVariance: Double?
    
    public init(
        id: UUID = UUID(),
        timestamp: Date,
        heartRate: Double? = nil,
        heartRateVariability: Double? = nil,
        motionMagnitude: Double? = nil,
        motionVariance: Double? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.heartRate = heartRate
        self.heartRateVariability = heartRateVariability
        self.motionMagnitude = motionMagnitude
        self.motionVariance = motionVariance
    }
}

/// Aggregated biometric data for analysis
public struct BiometricWindow: Codable {
    public let startTime: Date
    public let endTime: Date
    public let avgHeartRate: Double?
    public let hrvVariance: Double?
    public let avgMotion: Double?
    public let motionVariance: Double?
    public let dataPoints: [BiometricDataPoint]
    
    public init(
        startTime: Date,
        endTime: Date,
        dataPoints: [BiometricDataPoint]
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.dataPoints = dataPoints
        
        // Calculate aggregated values
        let heartRates = dataPoints.compactMap { $0.heartRate }
        self.avgHeartRate = heartRates.isEmpty ? nil : heartRates.reduce(0, +) / Double(heartRates.count)
        
        let hrvValues = dataPoints.compactMap { $0.heartRateVariability }
        if !hrvValues.isEmpty {
            let mean = hrvValues.reduce(0, +) / Double(hrvValues.count)
            self.hrvVariance = hrvValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(hrvValues.count)
        } else {
            self.hrvVariance = nil
        }
        
        let motionValues = dataPoints.compactMap { $0.motionMagnitude }
        self.avgMotion = motionValues.isEmpty ? nil : motionValues.reduce(0, +) / Double(motionValues.count)
        
        if !motionValues.isEmpty {
            let mean = motionValues.reduce(0, +) / Double(motionValues.count)
            self.motionVariance = motionValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(motionValues.count)
        } else {
            self.motionVariance = nil
        }
    }
}