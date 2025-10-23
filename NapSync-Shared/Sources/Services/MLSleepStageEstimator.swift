import Foundation
import CoreML
import NapSyncShared

/// ML-powered sleep stage estimator using trained CoreML models
class MLSleepStageEstimator {
    private var sleepStageModel: MLModel?
    private var optimalWakeModel: MLModel?
    private let personalizationEngine = PersonalizationEngine()
    
    init() {
        loadModels()
    }
    
    /// Loads the trained CoreML models
    private func loadModels() {
        Task {
            do {
                // Try to load existing models, or train new ones if they don't exist
                if let sleepModelURL = Bundle.main.url(forResource: "SleepStageClassifier", withExtension: "mlmodelc"),
                   let wakeModelURL = Bundle.main.url(forResource: "OptimalWakeTimeClassifier", withExtension: "mlmodelc") {
                    sleepStageModel = try MLModel(contentsOf: sleepModelURL)
                    optimalWakeModel = try MLModel(contentsOf: wakeModelURL)
                } else {
                    // Train models on first launch
                    await trainInitialModels()
                }
            } catch {
                print("Failed to load ML models: \(error)")
                // Fallback to heuristic-based estimation
            }
        }
    }
    
    /// Trains initial models with synthetic data
    private func trainInitialModels() async {
        do {
            let (sleepModel, wakeModel) = try await MLModelTrainer.trainModels()
            self.sleepStageModel = sleepModel
            self.optimalWakeModel = wakeModel
        } catch {
            print("Failed to train initial models: \(error)")
        }
    }
    
    /// Estimates sleep stage using ML model with fallback to heuristics
    func estimateSleepStage(
        from window: BiometricWindow,
        userProfile: UserProfile,
        timeInNap: TimeInterval,
        napDuration: TimeInterval
    ) -> SleepStageRecord {
        let timestamp = window.endTime
        
        // Try ML prediction first
        if let stage = predictSleepStageML(
            window: window,
            userProfile: userProfile,
            timeInNap: timeInNap,
            napDuration: napDuration
        ) {
            let confidence = calculateMLConfidence(window: window, predictedStage: stage)
            return SleepStageRecord(
                timestamp: timestamp,
                stage: stage,
                confidence: confidence,
                duration: window.endTime.timeIntervalSince(window.startTime)
            )
        }
        
        // Fallback to enhanced heuristics
        return estimateWithEnhancedHeuristics(window: window, timeInNap: timeInNap)
    }
    
    /// Predicts sleep stage using the trained ML model
    private func predictSleepStageML(
        window: BiometricWindow,
        userProfile: UserProfile,
        timeInNap: TimeInterval,
        napDuration: TimeInterval
    ) -> SleepStage? {
        guard let model = sleepStageModel,
              let heartRate = window.avgHeartRate,
              let hrv = window.hrvVariance,
              let motion = window.avgMotion else { return nil }
        
        do {
            let input = SleepStageClassifierInput(
                heartRate: heartRate,
                hrv: hrv,
                motion: motion,
                motionVariance: window.motionVariance ?? 0,
                timeInNap: timeInNap / 60.0, // Convert to minutes
                userAge: Double(userProfile.age),
                napDuration: napDuration / 60.0,
                timeOfDay: userProfile.timeOfDay,
                caffeineHours: userProfile.caffeineHours,
                sleepDebt: userProfile.sleepDebt
            )
            
            let prediction = try model.prediction(from: input)
            
            if let output = prediction.featureValue(for: "sleepStage")?.stringValue {
                return SleepStage(rawValue: output)
            }
        } catch {
            print("ML prediction failed: \(error)")
        }
        
        return nil
    }
    
    /// Calculates confidence in ML prediction
    private func calculateMLConfidence(window: BiometricWindow, predictedStage: SleepStage) -> Double {
        // Base confidence on data quality and model certainty
        var confidence = 0.8 // Base ML confidence
        
        // Adjust based on data completeness
        if window.avgHeartRate == nil { confidence -= 0.2 }
        if window.hrvVariance == nil { confidence -= 0.2 }
        if window.avgMotion == nil { confidence -= 0.1 }
        
        // Apply personalization adjustments
        confidence = personalizationEngine.adjustConfidence(
            confidence: confidence,
            stage: predictedStage,
            biometricWindow: window
        )
        
        return max(0.1, min(1.0, confidence))
    }
    
    /// Enhanced heuristic fallback method
    private func estimateWithEnhancedHeuristics(
        window: BiometricWindow,
        timeInNap: TimeInterval
    ) -> SleepStageRecord {
        guard let motion = window.avgMotion,
              let motionVariance = window.motionVariance,
              let hrv = window.hrvVariance else {
            return SleepStageRecord(
                timestamp: window.endTime,
                stage: .unknown,
                confidence: 0.3,
                duration: window.endTime.timeIntervalSince(window.startTime)
            )
        }
        
        // Enhanced heuristic algorithm with time-based adjustments
        let cyclePosition = (timeInNap / 60.0).truncatingRemainder(dividingBy: 90) // 90-min cycles
        
        var stage: SleepStage
        var confidence: Double
        
        // High motion indicates awakeness
        if motion > 0.8 || motionVariance > 0.5 {
            stage = .awake
            confidence = 0.9
        }
        // Very low motion + high HRV variance = deep sleep
        else if motion < 0.05 && hrv > 60 {
            stage = .deepSleep
            confidence = 0.8
        }
        // Moderate motion during REM periods
        else if cyclePosition > 60 && motion > 0.1 && motion < 0.4 {
            stage = .rem
            confidence = 0.7
        }
        // Default to light sleep
        else {
            stage = .lightSleep
            confidence = 0.6
        }
        
        return SleepStageRecord(
            timestamp: window.endTime,
            stage: stage,
            confidence: confidence,
            duration: window.endTime.timeIntervalSince(window.startTime)
        )
    }
    
    /// Determines optimal wake times using ML model
    func calculateOptimalWakeTimes(
        biometricWindows: [BiometricWindow],
        userProfile: UserProfile,
        napStartTime: Date,
        targetEndTime: Date
    ) -> [OptimalWakeTime] {
        var optimalTimes: [OptimalWakeTime] = []
        let wakeWindowStart = targetEndTime.addingTimeInterval(-15 * 60) // 15-minute window
        
        for window in biometricWindows {
            guard window.startTime >= wakeWindowStart && window.startTime <= targetEndTime else {
                continue
            }
            
            let timeInNap = window.startTime.timeIntervalSince(napStartTime)
            let isOptimal = predictOptimalWakeTimeML(
                window: window,
                userProfile: userProfile,
                timeInNap: timeInNap,
                targetEndTime: targetEndTime
            )
            
            if isOptimal {
                let sleepStage = estimateSleepStage(
                    from: window,
                    userProfile: userProfile,
                    timeInNap: timeInNap,
                    napDuration: targetEndTime.timeIntervalSince(napStartTime)
                )
                
                let optimalTime = OptimalWakeTime(
                    timestamp: window.endTime,
                    confidence: sleepStage.confidence,
                    sleepStage: sleepStage.stage,
                    reason: .lightSleepDetected
                )
                
                optimalTimes.append(optimalTime)
            }
        }
        
        return optimalTimes.sorted { $0.timestamp < $1.timestamp }
    }
    
    /// Predicts if current time is optimal for waking using ML
    private func predictOptimalWakeTimeML(
        window: BiometricWindow,
        userProfile: UserProfile,
        timeInNap: TimeInterval,
        targetEndTime: Date
    ) -> Bool {
        guard let model = optimalWakeModel,
              let heartRate = window.avgHeartRate,
              let hrv = window.hrvVariance,
              let motion = window.avgMotion else {
            return false
        }
        
        do {
            let timeRemaining = targetEndTime.timeIntervalSince(window.endTime) / 60.0 // Minutes
            
            let input = OptimalWakeTimeClassifierInput(
                heartRate: heartRate,
                hrv: hrv,
                motion: motion,
                motionVariance: window.motionVariance ?? 0,
                timeInNap: timeInNap / 60.0,
                userAge: Double(userProfile.age),
                napDuration: (timeInNap + timeRemaining) / 60.0,
                timeOfDay: userProfile.timeOfDay,
                caffeineHours: userProfile.caffeineHours,
                sleepDebt: userProfile.sleepDebt,
                timeRemaining: timeRemaining,
                sleepStage: predictCurrentSleepStage(window: window, timeInNap: timeInNap)
            )
            
            let prediction = try model.prediction(from: input)
            
            if let output = prediction.featureValue(for: "isOptimalWakeTime")?.int64Value {
                return output == 1
            }
        } catch {
            print("Optimal wake time ML prediction failed: \(error)")
        }
        
        return false
    }
    
    private func predictCurrentSleepStage(window: BiometricWindow, timeInNap: TimeInterval) -> String {
        // Quick heuristic for sleep stage as string input to wake time model
        guard let motion = window.avgMotion else { return "unknown" }
        
        if motion > 0.5 { return "awake" }
        if motion < 0.1 { return "deep_sleep" }
        return "light_sleep"
    }
    
    /// Updates models with user feedback for personalization
    func updateWithFeedback(_ feedback: NapFeedback) {
        personalizationEngine.processFeedback(feedback)
        
        // Trigger model retraining if enough feedback collected
        if personalizationEngine.shouldRetrain() {
            Task {
                await retrainWithPersonalizedData()
            }
        }
    }
    
    /// Retrains models with personalized data
    private func retrainWithPersonalizedData() async {
        let userFeedback = personalizationEngine.getAllFeedback()
        let userProfile = personalizationEngine.getUserProfile()
        
        let personalizedData = MLModelTrainer.generatePersonalizedData(
            userFeedback: userFeedback,
            baseProfile: userProfile
        )
        
        // In a production app, you'd implement incremental learning here
        // For the MVP, we'll log that retraining would occur
        print("🔄 Would retrain models with \(personalizedData.count) personalized data points")
    }
}

// MARK: - Model Input Types (would be auto-generated by CreateML)

struct SleepStageClassifierInput: MLFeatureProvider {
    let heartRate: Double
    let hrv: Double
    let motion: Double
    let motionVariance: Double
    let timeInNap: Double
    let userAge: Double
    let napDuration: Double
    let timeOfDay: Double
    let caffeineHours: Double
    let sleepDebt: Double
    
    var featureNames: Set<String> {
        return ["heartRate", "hrv", "motion", "motionVariance", "timeInNap", 
                "userAge", "napDuration", "timeOfDay", "caffeineHours", "sleepDebt"]
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "heartRate": return MLFeatureValue(double: heartRate)
        case "hrv": return MLFeatureValue(double: hrv)
        case "motion": return MLFeatureValue(double: motion)
        case "motionVariance": return MLFeatureValue(double: motionVariance)
        case "timeInNap": return MLFeatureValue(double: timeInNap)
        case "userAge": return MLFeatureValue(double: userAge)
        case "napDuration": return MLFeatureValue(double: napDuration)
        case "timeOfDay": return MLFeatureValue(double: timeOfDay)
        case "caffeineHours": return MLFeatureValue(double: caffeineHours)
        case "sleepDebt": return MLFeatureValue(double: sleepDebt)
        default: return nil
        }
    }
}

struct OptimalWakeTimeClassifierInput: MLFeatureProvider {
    let heartRate: Double
    let hrv: Double
    let motion: Double
    let motionVariance: Double
    let timeInNap: Double
    let userAge: Double
    let napDuration: Double
    let timeOfDay: Double
    let caffeineHours: Double
    let sleepDebt: Double
    let timeRemaining: Double
    let sleepStage: String
    
    var featureNames: Set<String> {
        return ["heartRate", "hrv", "motion", "motionVariance", "timeInNap",
                "userAge", "napDuration", "timeOfDay", "caffeineHours", "sleepDebt",
                "timeRemaining", "sleepStage"]
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        switch featureName {
        case "heartRate": return MLFeatureValue(double: heartRate)
        case "hrv": return MLFeatureValue(double: hrv)
        case "motion": return MLFeatureValue(double: motion)
        case "motionVariance": return MLFeatureValue(double: motionVariance)
        case "timeInNap": return MLFeatureValue(double: timeInNap)
        case "userAge": return MLFeatureValue(double: userAge)
        case "napDuration": return MLFeatureValue(double: napDuration)
        case "timeOfDay": return MLFeatureValue(double: timeOfDay)
        case "caffeineHours": return MLFeatureValue(double: caffeineHours)
        case "sleepDebt": return MLFeatureValue(double: sleepDebt)
        case "timeRemaining": return MLFeatureValue(double: timeRemaining)
        case "sleepStage": return MLFeatureValue(string: sleepStage)
        default: return nil
        }
    }
}