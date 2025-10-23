import Foundation

/// Processes raw biometric data into analyzable windows
public class BiometricProcessor {
    private let windowDuration: TimeInterval
    private let overlapRatio: Double
    
    public init(windowDuration: TimeInterval = 30.0, overlapRatio: Double = 0.5) {
        self.windowDuration = windowDuration
        self.overlapRatio = overlapRatio
    }
    
    /// Creates sliding windows from biometric data points
    public func createWindows(from dataPoints: [BiometricDataPoint]) -> [BiometricWindow] {
        guard !dataPoints.isEmpty else { return [] }
        
        let sortedPoints = dataPoints.sorted { $0.timestamp < $1.timestamp }
        var windows: [BiometricWindow] = []
        
        let stepSize = windowDuration * (1.0 - overlapRatio)
        let startTime = sortedPoints.first!.timestamp
        let endTime = sortedPoints.last!.timestamp
        
        var currentTime = startTime
        
        while currentTime.addingTimeInterval(windowDuration) <= endTime {
            let windowStart = currentTime
            let windowEnd = currentTime.addingTimeInterval(windowDuration)
            
            let windowPoints = sortedPoints.filter { point in
                point.timestamp >= windowStart && point.timestamp < windowEnd
            }
            
            if !windowPoints.isEmpty {
                let window = BiometricWindow(
                    startTime: windowStart,
                    endTime: windowEnd,
                    dataPoints: windowPoints
                )
                windows.append(window)
            }
            
            currentTime = currentTime.addingTimeInterval(stepSize)
        }
        
        return windows
    }
    
    /// Filters out invalid or unrealistic biometric data
    public func filterValidData(_ dataPoints: [BiometricDataPoint]) -> [BiometricDataPoint] {
        return dataPoints.filter { point in
            // Heart rate validation (40-200 bpm)
            if let hr = point.heartRate {
                guard hr >= 40 && hr <= 200 else { return false }
            }
            
            // HRV validation (5-200 ms)
            if let hrv = point.heartRateVariability {
                guard hrv >= 5 && hrv <= 200 else { return false }
            }
            
            // Motion validation (0-10 g)
            if let motion = point.motionMagnitude {
                guard motion >= 0 && motion <= 10 else { return false }
            }
            
            return true
        }
    }
    
    /// Smooths data using moving average
    public func smoothData(_ dataPoints: [BiometricDataPoint], windowSize: Int = 5) -> [BiometricDataPoint] {
        guard dataPoints.count >= windowSize else { return dataPoints }
        
        var smoothedPoints: [BiometricDataPoint] = []
        
        for i in 0..<dataPoints.count {
            let startIndex = max(0, i - windowSize / 2)
            let endIndex = min(dataPoints.count - 1, i + windowSize / 2)
            
            let window = Array(dataPoints[startIndex...endIndex])
            
            let avgHeartRate = window.compactMap { $0.heartRate }.average
            let avgHRV = window.compactMap { $0.heartRateVariability }.average
            let avgMotion = window.compactMap { $0.motionMagnitude }.average
            
            let smoothedPoint = BiometricDataPoint(
                id: dataPoints[i].id,
                timestamp: dataPoints[i].timestamp,
                heartRate: avgHeartRate,
                heartRateVariability: avgHRV,
                motionMagnitude: avgMotion,
                motionVariance: dataPoints[i].motionVariance
            )
            
            smoothedPoints.append(smoothedPoint)
        }
        
        return smoothedPoints
    }
}

extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}