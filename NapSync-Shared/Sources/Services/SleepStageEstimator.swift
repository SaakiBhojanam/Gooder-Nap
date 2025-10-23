import Foundation

/// ML-Enhanced sleep stage estimation service with fallback heuristics
public class SleepStageEstimator {
    private let thresholds: SleepThresholds
    private let mlEstimator: MLSleepStageEstimator
    
    public init(thresholds: SleepThresholds = .default) {
        self.thresholds = thresholds
        self.mlEstimator = MLSleepStageEstimator()
    }
    
    /// Estimates sleep stage using ML models with heuristic fallback
    public func estimateSleepStage(
        from window: BiometricWindow,
        userProfile: UserProfile? = nil,
        timeInNap: TimeInterval = 0,
        napDuration: TimeInterval = 0
    ) -> SleepStageRecord {
        // Use ML estimation if user profile is available
        if let profile = userProfile {
            return mlEstimator.estimateSleepStage(
                from: window,
                userProfile: profile,
                timeInNap: timeInNap,
                napDuration: napDuration
            )
        }
        
        // Fallback to heuristic estimation
        let timestamp = window.endTime
        let stage = classifySleepStage(window: window)
        let confidence = calculateConfidence(for: stage, window: window)
        let duration = window.endTime.timeIntervalSince(window.startTime)
        
        return SleepStageRecord(
            timestamp: timestamp,
            stage: stage,
            confidence: confidence,
            duration: duration
        )
    }
    
    /// Updates ML models with user feedback
    public func updateWithFeedback(_ feedback: NapFeedback) {
        mlEstimator.updateWithFeedback(feedback)
    }
    
    private func classifySleepStage(window: BiometricWindow) -> SleepStage {
        guard let motion = window.avgMotion,
              let motionVariance = window.motionVariance,
              let hrvVariance = window.hrvVariance else {
            return .unknown
        }
        
        // MVP Heuristic Algorithm
        let isLowMotion = motion < thresholds.lowMotionThreshold
        let isStableMotion = motionVariance < thresholds.motionVarianceThreshold
        let isStableHRV = hrvVariance < thresholds.hrvVarianceThreshold
        let isHighMotion = motion > thresholds.highMotionThreshold
        
        // Classification logic
        if isHighMotion || motionVariance > thresholds.highMotionVarianceThreshold {
            return .awake
        }
        
        if isLowMotion && isStableMotion && isStableHRV {
            return .deepSleep
        }
        
        if !isLowMotion || !isStableHRV {
            return .lightSleep
        }
        
        return .lightSleep // Default to light sleep for optimal wake detection
    }
    
    private func calculateConfidence(for stage: SleepStage, window: BiometricWindow) -> Double {
        guard let motion = window.avgMotion,
              let motionVariance = window.motionVariance,
              let hrvVariance = window.hrvVariance else {
            return 0.3 // Low confidence for incomplete data
        }
        
        var confidence: Double = 0.5
        
        switch stage {
        case .deepSleep:
            confidence = min(1.0, 0.3 + 
                (1.0 - min(1.0, motion / thresholds.lowMotionThreshold)) * 0.4 +
                (1.0 - min(1.0, hrvVariance / thresholds.hrvVarianceThreshold)) * 0.3)
            
        case .lightSleep:
            confidence = 0.6 + min(0.3, motionVariance / thresholds.motionVarianceThreshold * 0.3)
            
        case .awake:
            confidence = min(1.0, 0.4 + (motion / thresholds.highMotionThreshold) * 0.6)
            
        default:
            confidence = 0.3
        }
        
        return max(0.1, min(1.0, confidence))
    }
}

/// Thresholds for sleep stage classification
public struct SleepThresholds {
    public let lowMotionThreshold: Double
    public let highMotionThreshold: Double
    public let motionVarianceThreshold: Double
    public let highMotionVarianceThreshold: Double
    public let hrvVarianceThreshold: Double
    
    public static let `default` = SleepThresholds(
        lowMotionThreshold: 0.1,
        highMotionThreshold: 0.5,
        motionVarianceThreshold: 0.05,
        highMotionVarianceThreshold: 0.3,
        hrvVarianceThreshold: 50.0
    )
    
    public init(
        lowMotionThreshold: Double,
        highMotionThreshold: Double,
        motionVarianceThreshold: Double,
        highMotionVarianceThreshold: Double,
        hrvVarianceThreshold: Double
    ) {
        self.lowMotionThreshold = lowMotionThreshold
        self.highMotionThreshold = highMotionThreshold
        self.motionVarianceThreshold = motionVarianceThreshold
        self.highMotionVarianceThreshold = highMotionVarianceThreshold
        self.hrvVarianceThreshold = hrvVarianceThreshold
    }
}
