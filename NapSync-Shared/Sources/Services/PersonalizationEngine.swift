import Foundation
import NapSyncShared

/// Personalization engine that learns from user feedback to improve wake time predictions
class PersonalizationEngine {
    private var userFeedbackHistory: [NapFeedback] = []
    private var userProfile: UserProfile
    private var personalizedAdjustments: [String: Double] = [:]
    private let feedbackThreshold = 10 // Retrain after 10 feedback sessions
    
    init() {
        // Initialize with default user profile
        self.userProfile = UserProfile(
            age: 30,
            weight: 70,
            restingHeartRate: 65,
            baselineHRV: 40,
            timeOfDay: 14, // 2 PM default nap time
            caffeineHours: 4,
            sleepDebt: 1
        )
        
        loadStoredFeedback()
        calculatePersonalizedAdjustments()
    }
    
    /// Processes new user feedback and updates personalization parameters
    func processFeedback(_ feedback: NapFeedback) {
        userFeedbackHistory.append(feedback)
        
        // Update user profile based on feedback patterns
        updateUserProfile(from: feedback)
        
        // Recalculate personalized adjustments
        calculatePersonalizedAdjustments()
        
        // Store feedback for persistence
        storeFeedback()
        
        print("📊 Processed feedback: Quality \(feedback.qualityRating)/5, Feeling: \(feedback.postNapFeeling)")
        print("🎯 Total feedback sessions: \(userFeedbackHistory.count)")
    }
    
    /// Updates user profile based on feedback patterns
    private func updateUserProfile(from feedback: NapFeedback) {
        let session = feedback.napSession
        
        // Update preferred nap time
        let napHour = Calendar.current.component(.hour, from: session.startTime)
        userProfile = UserProfile(
            age: userProfile.age,
            weight: userProfile.weight,
            restingHeartRate: calculateAverageRestingHR(),
            baselineHRV: calculateAverageHRV(),
            timeOfDay: Double(napHour),
            caffeineHours: userProfile.caffeineHours,
            sleepDebt: userProfile.sleepDebt
        )
    }
    
    /// Calculates personalized adjustments based on feedback history
    private func calculatePersonalizedAdjustments() {
        guard !userFeedbackHistory.isEmpty else { return }
        
        // Analyze patterns in successful vs unsuccessful wake times
        let successfulWakes = userFeedbackHistory.filter { $0.qualityRating >= 4 }
        let unsuccessfulWakes = userFeedbackHistory.filter { $0.qualityRating <= 2 }
        
        // Calculate stage preferences
        calculateSleepStagePreferences(successful: successfulWakes, unsuccessful: unsuccessfulWakes)
        
        // Calculate biometric thresholds
        calculateBiometricThresholds(successful: successfulWakes, unsuccessful: unsuccessfulWakes)
        
        // Calculate timing preferences
        calculateTimingPreferences(successful: successfulWakes, unsuccessful: unsuccessfulWakes)
    }
    
    /// Analyzes which sleep stages work best for this user
    private func calculateSleepStagePreferences(
        successful: [NapFeedback],
        unsuccessful: [NapFeedback]
    ) {
        let sleepStages = SleepStage.allCases.filter { $0 != .unknown }
        
        for stage in sleepStages {
            let successfulInStage = successful.filter { feedback in
                feedback.sessionBiometrics.last?.let { biometric in
                    inferSleepStage(from: biometric) == stage
                } ?? false
            }.count
            
            let unsuccessfulInStage = unsuccessful.filter { feedback in
                feedback.sessionBiometrics.last?.let { biometric in
                    inferSleepStage(from: biometric) == stage
                } ?? false
            }.count
            
            let totalInStage = successfulInStage + unsuccessfulInStage
            if totalInStage > 0 {
                let successRate = Double(successfulInStage) / Double(totalInStage)
                personalizedAdjustments["stage_\(stage.rawValue)"] = successRate
            }
        }
    }
    
    /// Calculates personalized biometric thresholds
    private func calculateBiometricThresholds(
        successful: [NapFeedback],
        unsuccessful: [NapFeedback]
    ) {
        // Heart rate thresholds
        let successfulHR = successful.compactMap { $0.sessionBiometrics.last?.heartRate }
        let unsuccessfulHR = unsuccessful.compactMap { $0.sessionBiometrics.last?.heartRate }
        
        if !successfulHR.isEmpty && !unsuccessfulHR.isEmpty {
            let avgSuccessfulHR = successfulHR.reduce(0, +) / Double(successfulHR.count)
            let avgUnsuccessfulHR = unsuccessfulHR.reduce(0, +) / Double(unsuccessfulHR.count)
            personalizedAdjustments["hr_preference"] = avgSuccessfulHR - avgUnsuccessfulHR
        }
        
        // Motion thresholds
        let successfulMotion = successful.compactMap { $0.sessionBiometrics.last?.motionMagnitude }
        let unsuccessfulMotion = unsuccessful.compactMap { $0.sessionBiometrics.last?.motionMagnitude }
        
        if !successfulMotion.isEmpty && !unsuccessfulMotion.isEmpty {
            let avgSuccessfulMotion = successfulMotion.reduce(0, +) / Double(successfulMotion.count)
            let avgUnsuccessfulMotion = unsuccessfulMotion.reduce(0, +) / Double(unsuccessfulMotion.count)
            personalizedAdjustments["motion_preference"] = avgSuccessfulMotion - avgUnsuccessfulMotion
        }
    }
    
    /// Calculates timing preferences (early vs late wake)
    private func calculateTimingPreferences(
        successful: [NapFeedback],
        unsuccessful: [NapFeedback]
    ) {
        let successfulTimings = successful.map { feedback in
            let targetTime = feedback.napSession.targetEndTime
            let actualTime = feedback.napSession.actualEndTime ?? targetTime
            return actualTime.timeIntervalSince(targetTime) // Negative = early, Positive = late
        }
        
        if !successfulTimings.isEmpty {
            let avgTiming = successfulTimings.reduce(0, +) / Double(successfulTimings.count)
            personalizedAdjustments["timing_preference"] = avgTiming / 60.0 // Convert to minutes
        }
    }
    
    /// Adjusts ML model confidence based on personalized patterns
    func adjustConfidence(
        confidence: Double,
        stage: SleepStage,
        biometricWindow: BiometricWindow
    ) -> Double {
        var adjustedConfidence = confidence
        
        // Apply stage-based adjustments
        if let stagePreference = personalizedAdjustments["stage_\(stage.rawValue)"] {
            // If this stage historically works well for the user, increase confidence
            let adjustment = (stagePreference - 0.5) * 0.2 // Max ±0.1 adjustment
            adjustedConfidence += adjustment
        }
        
        // Apply biometric-based adjustments
        if let hrPreference = personalizedAdjustments["hr_preference"],
           let currentHR = biometricWindow.avgHeartRate {
            let hrDiff = abs(currentHR - (userProfile.restingHeartRate + hrPreference))
            if hrDiff < 5 { // Within 5 BPM of preferred
                adjustedConfidence += 0.1
            }
        }
        
        if let motionPreference = personalizedAdjustments["motion_preference"],
           let currentMotion = biometricWindow.avgMotion {
            let motionDiff = abs(currentMotion - motionPreference)
            if motionDiff < 0.1 { // Within preferred motion range
                adjustedConfidence += 0.1
            }
        }
        
        return max(0.1, min(1.0, adjustedConfidence))
    }
    
    /// Determines if models should be retrained based on feedback volume
    func shouldRetrain() -> Bool {
        return userFeedbackHistory.count >= feedbackThreshold &&
               userFeedbackHistory.count % feedbackThreshold == 0
    }
    
    /// Gets all collected user feedback for model retraining
    func getAllFeedback() -> [NapFeedback] {
        return userFeedbackHistory
    }
    
    /// Gets current user profile
    func getUserProfile() -> UserProfile {
        return userProfile
    }
    
    /// Provides personalized wake time recommendations
    func getPersonalizedWakeRecommendation(
        currentBiometrics: BiometricWindow,
        timeInNap: TimeInterval,
        targetEndTime: Date
    ) -> PersonalizedRecommendation {
        let timeRemaining = targetEndTime.timeIntervalSince(Date())
        
        // Check if current conditions match user's historical preferences
        let conditionScore = calculateConditionScore(biometrics: currentBiometrics)
        
        // Apply timing preference
        var recommendedWakeTime = targetEndTime
        if let timingPref = personalizedAdjustments["timing_preference"] {
            recommendedWakeTime = targetEndTime.addingTimeInterval(timingPref * 60)
        }
        
        return PersonalizedRecommendation(
            recommendedWakeTime: recommendedWakeTime,
            confidenceScore: conditionScore,
            reasoning: generateRecommendationReasoning(
                conditionScore: conditionScore,
                timeRemaining: timeRemaining
            )
        )
    }
    
    /// Calculates how well current conditions match user preferences
    private func calculateConditionScore(biometrics: BiometricWindow) -> Double {
        var score = 0.5 // Base score
        let maxAdjustment = 0.4
        
        // Heart rate matching
        if let hrPref = personalizedAdjustments["hr_preference"],
           let currentHR = biometrics.avgHeartRate {
            let hrDiff = abs(currentHR - (userProfile.restingHeartRate + hrPref))
            let hrScore = max(0, 1 - (hrDiff / 20.0)) // Normalize by 20 BPM range
            score += (hrScore - 0.5) * maxAdjustment * 0.4
        }
        
        // Motion matching
        if let motionPref = personalizedAdjustments["motion_preference"],
           let currentMotion = biometrics.avgMotion {
            let motionDiff = abs(currentMotion - motionPref)
            let motionScore = max(0, 1 - (motionDiff / 1.0)) // Normalize by 1.0 motion unit
            score += (motionScore - 0.5) * maxAdjustment * 0.6
        }
        
        return max(0.1, min(0.9, score))
    }
    
    /// Generates human-readable reasoning for recommendations
    private func generateRecommendationReasoning(
        conditionScore: Double,
        timeRemaining: TimeInterval
    ) -> String {
        let minutesRemaining = Int(timeRemaining / 60)
        
        if conditionScore > 0.7 {
            return "Great time to wake up! Your current biometrics match your historical preferences for refreshing naps."
        } else if conditionScore > 0.5 {
            return "Good wake window. Your body shows signs that align with previous successful wake times."
        } else if minutesRemaining < 5 {
            return "Close to target time. Based on your patterns, waking now would be acceptable."
        } else {
            return "Consider waiting a bit longer. Your current state doesn't match your typical preferences for optimal waking."
        }
    }
    
    // MARK: - Helper Methods
    
    private func calculateAverageRestingHR() -> Double {
        let recentHRData = userFeedbackHistory.suffix(5).compactMap { feedback in
            feedback.sessionBiometrics.first?.heartRate
        }
        
        return recentHRData.isEmpty ? userProfile.restingHeartRate : 
               recentHRData.reduce(0, +) / Double(recentHRData.count)
    }
    
    private func calculateAverageHRV() -> Double {
        let recentHRVData = userFeedbackHistory.suffix(5).compactMap { feedback in
            feedback.sessionBiometrics.first?.heartRateVariability
        }
        
        return recentHRVData.isEmpty ? userProfile.baselineHRV :
               recentHRVData.reduce(0, +) / Double(recentHRVData.count)
    }
    
    private func inferSleepStage(from biometric: BiometricDataPoint) -> SleepStage {
        guard let motion = biometric.motionMagnitude else { return .unknown }
        
        if motion > 0.5 { return .awake }
        if motion < 0.1 { return .deepSleep }
        return .lightSleep
    }
    
    private func loadStoredFeedback() {
        // In a real app, load from CoreData or UserDefaults
        // For MVP, we'll start with empty history
    }
    
    private func storeFeedback() {
        // In a real app, persist to CoreData
        // For MVP, we'll keep in memory
    }
}

// MARK: - Supporting Types

struct PersonalizedRecommendation {
    let recommendedWakeTime: Date
    let confidenceScore: Double
    let reasoning: String
}

extension Optional {
    func `let`<U>(_ transform: (Wrapped) -> U) -> U? {
        return self.map(transform)
    }
}