import Foundation

public struct TimeUtils {
    /// Formats a time interval into a human-readable string
    public static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
    
    /// Formats a time interval into a short format (e.g., "1h 30m")
    public static func formatDurationShort(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    /// Creates time windows for data analysis
    public static func createTimeWindows(
        start: Date,
        end: Date,
        windowSize: TimeInterval,
        overlap: Double = 0.5
    ) -> [(start: Date, end: Date)] {
        var windows: [(start: Date, end: Date)] = []
        let stepSize = windowSize * (1.0 - overlap)
        
        var currentStart = start
        while currentStart.addingTimeInterval(windowSize) <= end {
            let windowEnd = currentStart.addingTimeInterval(windowSize)
            windows.append((start: currentStart, end: windowEnd))
            currentStart = currentStart.addingTimeInterval(stepSize)
        }
        
        return windows
    }
    
    /// Calculates the sleep phase based on time since sleep onset
    public static func estimatedSleepPhase(timeSinceOnset: TimeInterval) -> SleepStage {
        let minutes = timeSinceOnset / 60.0
        
        // Simplified sleep cycle model (90-minute cycles)
        let cyclePosition = minutes.truncatingRemainder(dividingBy: 90)
        
        switch cyclePosition {
        case 0..<15:
            return .lightSleep
        case 15..<45:
            return .deepSleep
        case 45..<75:
            return .deepSleep
        case 75..<90:
            return .lightSleep
        default:
            return .lightSleep
        }
    }
}