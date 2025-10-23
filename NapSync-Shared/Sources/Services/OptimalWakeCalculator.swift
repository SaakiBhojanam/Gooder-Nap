import Foundation

/// ML-Enhanced optimal wake time calculator with personalization
public class OptimalWakeCalculator {
    private let configuration: NapConfiguration
    private let mlEstimator: MLSleepStageEstimator
    private let personalizationEngine: PersonalizationEngine
    
    public init(configuration: NapConfiguration = .default) {
        self.configuration = configuration
        self.mlEstimator = MLSleepStageEstimator()
        self.personalizationEngine = PersonalizationEngine()
    }
    
    /// Finds optimal wake times using ML predictions and personalization
    public func calculateOptimalWakeTimes(
        biometricWindows: [BiometricWindow],
        userProfile: UserProfile,
        napStartTime: Date,
        targetEndTime: Date
    ) -> [OptimalWakeTime] {
        // Use ML-powered optimal wake time calculation
        return mlEstimator.calculateOptimalWakeTimes(
            biometricWindows: biometricWindows,
            userProfile: userProfile,
            napStartTime: napStartTime,
            targetEndTime: targetEndTime
        )
    }
    
    /// Gets personalized wake recommendation
    public func getPersonalizedRecommendation(
        currentBiometrics: BiometricWindow,
        timeInNap: TimeInterval,
        targetEndTime: Date
    ) -> PersonalizedRecommendation {
        return personalizationEngine.getPersonalizedWakeRecommendation(
            currentBiometrics: currentBiometrics,
            timeInNap: timeInNap,
            targetEndTime: targetEndTime
        )
    }
    
    /// Gets the best wake time from available options
    public func getBestWakeTime(
        optimalTimes: [OptimalWakeTime],
        targetEndTime: Date,
        currentTime: Date = Date()
    ) -> OptimalWakeTime? {
        // Filter to times that haven't passed yet
        let availableTimes = optimalTimes.filter { $0.timestamp >= currentTime }
        
        guard !availableTimes.isEmpty else {
            // No optimal times available, wake at target time
            return OptimalWakeTime(
                timestamp: targetEndTime,
                confidence: 1.0,
                sleepStage: .unknown,
                reason: .targetTimeReached
            )
        }
        
        // Prefer the latest time with highest confidence
        return availableTimes.max { lhs, rhs in
            if abs(lhs.confidence - rhs.confidence) > 0.1 {
                return lhs.confidence < rhs.confidence
            }
            return lhs.timestamp < rhs.timestamp
        }
    }
    
    /// Determines if it's time to wake the user
    public func shouldWakeUser(
        optimalTimes: [OptimalWakeTime],
        targetEndTime: Date,
        currentTime: Date = Date()
    ) -> (shouldWake: Bool, wakeTime: OptimalWakeTime?) {
        let timeUntilTarget = targetEndTime.timeIntervalSince(currentTime)
        
        // Always wake if past target time
        if timeUntilTarget <= 0 {
            let wakeTime = OptimalWakeTime(
                timestamp: targetEndTime,
                confidence: 1.0,
                sleepStage: .unknown,
                reason: .targetTimeReached
            )
            return (true, wakeTime)
        }
        
        // Check if we have an optimal time in the next 2 minutes
        if let bestTime = getBestWakeTime(optimalTimes: optimalTimes, targetEndTime: targetEndTime, currentTime: currentTime),
           bestTime.timestamp.timeIntervalSince(currentTime) <= 120 {
            return (true, bestTime)
        }
        
        // Wake if within 1 minute of target and no optimal times coming
        if timeUntilTarget <= 60 {
            let wakeTime = OptimalWakeTime(
                timestamp: targetEndTime,
                confidence: 0.8,
                sleepStage: .unknown,
                reason: .targetTimeReached
            )
            return (true, wakeTime)
        }
        
        return (false, nil)
    }
    
    private func determineWakeReason(for record: SleepStageRecord) -> WakeReason {
        switch record.stage {
        case .lightSleep:
            return .lightSleepDetected
        case .awake:
            return .motionIncrease
        default:
            return .heartRateChange
        }
    }
}
