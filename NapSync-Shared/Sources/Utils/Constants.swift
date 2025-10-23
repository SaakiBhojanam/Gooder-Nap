import Foundation

public struct Constants {
    // MARK: - Sleep Analysis
    public struct SleepAnalysis {
        public static let defaultWindowSize: TimeInterval = 30.0 // seconds
        public static let minimumDataPoints = 5
        public static let confidenceThreshold = 0.7
        public static let maxHeartRate = 200.0
        public static let minHeartRate = 40.0
        public static let maxHRV = 200.0
        public static let minHRV = 5.0
        public static let maxMotion = 10.0
    }
    
    // MARK: - Nap Configuration
    public struct NapConfig {
        public static let minNapDuration: TimeInterval = 10 * 60 // 10 minutes
        public static let maxNapDuration: TimeInterval = 180 * 60 // 3 hours
        public static let defaultNapDuration: TimeInterval = 90 * 60 // 90 minutes
        public static let wakeWindowDuration: TimeInterval = 10 * 60 // 10 minutes
        public static let monitoringInterval: TimeInterval = 30.0 // seconds
    }
    
    // MARK: - Watch Communication
    public struct WatchComm {
        public static let maxRetries = 3
        public static let timeoutInterval: TimeInterval = 10.0
        public static let heartbeatInterval: TimeInterval = 60.0
    }
    
    // MARK: - UI Constants
    public struct UI {
        public static let animationDuration = 0.3
        public static let hapticFeedbackDelay = 0.1
        public static let progressRingWidth: CGFloat = 8.0
        public static let cornerRadius: CGFloat = 15.0
    }
}