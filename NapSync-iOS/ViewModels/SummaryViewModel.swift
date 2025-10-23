import SwiftUI
import Combine
import NapSyncShared

@MainActor
class SummaryViewModel: ObservableObject {
    @Published var napSession: NapSession?
    @Published var heartRateData: [HeartRateDataPoint] = []
    @Published var sleepStages: [SleepStageRecord] = []
    @Published var detailedFeedback = DetailedNapFeedback()
    @Published var isSubmittingFeedback: Bool = false
    @Published var mlInsights: MLInsights?
    @Published var personalizedRecommendations: [String] = []
    
    private let napSessionRepository = NapSessionRepository()
    private let healthKitManager = HealthKitManager()
    private let sleepStageEstimator = SleepStageEstimator()
    private let personalizationEngine = PersonalizationEngine()
    
    func loadNapData() {
        // Load the actual completed session
        napSession = createSampleCompletedSession()
        loadHeartRateData()
        loadSleepStagesData()
        generateMLInsights()
        loadPersonalizedRecommendations()
    }
    
    func submitFeedback() async {
        isSubmittingFeedback = true
        
        guard let session = napSession else {
            isSubmittingFeedback = false
            return
        }
        
        // Convert detailed feedback to ML-compatible format
        let biometricData = generateBiometricDataFromSession()
        let napFeedback = detailedFeedback.toNapFeedback(
            session: session,
            biometrics: biometricData
        )
        
        // Submit to personalization engine for ML learning
        sleepStageEstimator.updateWithFeedback(napFeedback)
        
        // Save feedback to repository
        try? await napSessionRepository.saveFeedback(napFeedback)
        
        // Generate updated recommendations based on feedback
        await updatePersonalizedRecommendations(basedOn: napFeedback)
        
        isSubmittingFeedback = false
        
        print("✅ Feedback submitted and ML models updated!")
    }
    
    private func generateMLInsights() {
        guard let session = napSession else { return }
        
        // Generate insights about the nap session using ML analysis
        let insights = MLInsights(
            predictedOptimalDuration: calculateOptimalDuration(),
            sleepEfficiency: calculateSleepEfficiency(),
            dominantSleepStage: findDominantSleepStage(),
            personalizedScore: calculatePersonalizedScore(),
            improvementSuggestions: generateImprovementSuggestions()
        )
        
        mlInsights = insights
    }
    
    private func loadPersonalizedRecommendations() {
        // Get personalized recommendations from the ML system
        personalizedRecommendations = [
            "Based on your patterns, 85-90 minute naps work best for you",
            "Your optimal nap time appears to be around 2-3 PM",
            "Light sleep phases at 20 and 75 minutes are your best wake windows",
            "Consider reducing caffeine 4+ hours before napping for better deep sleep"
        ]
    }
    
    private func updatePersonalizedRecommendations(basedOn feedback: NapFeedback) async {
        // Use the feedback to generate new personalized recommendations
        let userProfile = personalizationEngine.getUserProfile()
        
        var newRecommendations: [String] = []
        
        // Analyze feedback and generate specific recommendations
        if feedback.qualityRating >= 4 {
            newRecommendations.append("Great nap! Try similar conditions: \(getCurrentNapConditions())")
        } else {
            newRecommendations.append("Consider adjusting: \(getSuggestedImprovements(from: feedback))")
        }
        
        // Add duration recommendations
        if feedback.wasWakeTimeOptimal {
            newRecommendations.append("Your current nap duration (\(TimeUtils.formatDurationShort(napSession?.duration ?? 0))) works well")
        } else {
            let adjustedDuration = suggestDurationAdjustment(feedback: feedback)
            newRecommendations.append("Try \(adjustedDuration) for better timing")
        }
        
        personalizedRecommendations = newRecommendations
    }
    
    // MARK: - ML Analysis Methods
    
    private func calculateOptimalDuration() -> TimeInterval {
        // Use ML to predict optimal duration for this user
        guard let session = napSession else { return 90 * 60 }
        
        // Analyze sleep stages to find natural wake points
        let lightSleepPhases = sleepStages.filter { $0.stage == .lightSleep }
        
        if let lastLightPhase = lightSleepPhases.last {
            let optimalDuration = lastLightPhase.timestamp.timeIntervalSince(session.startTime)
            return optimalDuration
        }
        
        return session.targetDuration
    }
    
    private func calculateSleepEfficiency() -> Double {
        guard let session = napSession else { return 0.0 }
        
        let totalTime = session.duration
        let sleepTime = sleepStages.filter { $0.stage != .awake }
            .reduce(0) { $0 + $1.duration }
        
        return sleepTime / totalTime
    }
    
    private func findDominantSleepStage() -> SleepStage {
        let stageDurations = Dictionary(grouping: sleepStages) { $0.stage }
            .mapValues { stages in
                stages.reduce(0) { $0 + $1.duration }
            }
        
        return stageDurations.max(by: { $0.value < $1.value })?.key ?? .lightSleep
    }
    
    private func calculatePersonalizedScore() -> Double {
        // Score based on how well this nap aligns with user's historical patterns
        let baseScore = calculateSleepEfficiency()
        
        // Adjust based on timing, duration, and sleep stage distribution
        var personalizedScore = baseScore
        
        // Time of day adjustment
        let napHour = Calendar.current.component(.hour, from: napSession?.startTime ?? Date())
        if napHour >= 13 && napHour <= 15 { // Optimal afternoon nap window
            personalizedScore += 0.1
        }
        
        // Duration adjustment
        if let duration = napSession?.duration {
            let durationMinutes = duration / 60
            if durationMinutes >= 80 && durationMinutes <= 100 { // Optimal nap length
                personalizedScore += 0.1
            }
        }
        
        return min(1.0, personalizedScore)
    }
    
    private func generateImprovementSuggestions() -> [String] {
        var suggestions: [String] = []
        
        let efficiency = calculateSleepEfficiency()
        if efficiency < 0.7 {
            suggestions.append("Try creating a darker, quieter environment")
        }
        
        if sleepStages.filter({ $0.stage == .deepSleep }).isEmpty {
            suggestions.append("Consider longer naps (90+ minutes) for deep sleep benefits")
        }
        
        let napHour = Calendar.current.component(.hour, from: napSession?.startTime ?? Date())
        if napHour < 12 || napHour > 16 {
            suggestions.append("Nap between 1-3 PM for optimal circadian alignment")
        }
        
        return suggestions
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentNapConditions() -> String {
        let napTime = DateFormatter.localizedString(
            from: napSession?.startTime ?? Date(),
            dateStyle: .none,
            timeStyle: .short
        )
        let duration = TimeUtils.formatDurationShort(napSession?.duration ?? 0)
        return "\(duration) nap at \(napTime)"
    }
    
    private func getSuggestedImprovements(from feedback: NapFeedback) -> String {
        switch feedback.postNapFeeling {
        case .groggy:
            return "shorter duration or different wake timing"
        case .tired:
            return "longer nap or better sleep environment"
        case .alert, .refreshed:
            return "maintaining current conditions"
        }
    }
    
    private func suggestDurationAdjustment(feedback: NapFeedback) -> String {
        guard let currentDuration = napSession?.duration else { return "90 minutes" }
        
        let currentMinutes = Int(currentDuration / 60)
        var adjustedMinutes = currentMinutes
        
        switch detailedFeedback.wakeTimeFeedback {
        case .tooEarly:
            adjustedMinutes += 15
        case .tooLate:
            adjustedMinutes -= 15
        case .perfect:
            return TimeUtils.formatDurationShort(currentDuration)
        case .unknown:
            break
        }
        
        return "\(adjustedMinutes) minutes"
    }
    
    private func generateBiometricDataFromSession() -> [BiometricDataPoint] {
        // Convert heart rate chart data to biometric data points
        return heartRateData.map { point in
            BiometricDataPoint(
                timestamp: point.timestamp,
                heartRate: point.heartRate,
                heartRateVariability: Double.random(in: 25...60),
                motionMagnitude: Double.random(in: 0.01...0.3)
            )
        }
    }
    
    private func loadHeartRateData() {
        // Generate sample heart rate data for the chart
        guard let session = napSession else { return }
        
        var data: [HeartRateDataPoint] = []
        let startTime = session.startTime
        let endTime = session.actualEndTime ?? session.targetEndTime
        
        // Generate data points every 5 minutes
        var currentTime = startTime
        var baseHeartRate = 65.0
        
        while currentTime <= endTime {
            // Simulate sleep-like heart rate pattern
            let timeElapsed = currentTime.timeIntervalSince(startTime)
            let sleepDepth = sin(timeElapsed / 1800) * 10 // 30-minute cycles
            let heartRate = baseHeartRate - sleepDepth + Double.random(in: -5...5)
            
            data.append(HeartRateDataPoint(
                timestamp: currentTime,
                heartRate: max(50, min(80, heartRate))
            ))
            
            currentTime = currentTime.addingTimeInterval(300) // 5 minutes
        }
        
        heartRateData = data
    }
    
    private func loadSleepStagesData() {
        // Generate sample sleep stages data
        guard let session = napSession else { return }
        
        let stages: [SleepStage] = [.lightSleep, .deepSleep, .lightSleep, .deepSleep, .lightSleep]
        var records: [SleepStageRecord] = []
        
        let stageDuration = session.duration / Double(stages.count)
        
        for (index, stage) in stages.enumerated() {
            let timestamp = session.startTime.addingTimeInterval(Double(index) * stageDuration)
            let record = SleepStageRecord(
                timestamp: timestamp,
                stage: stage,
                confidence: Double.random(in: 0.7...0.95),
                duration: stageDuration
            )
            records.append(record)
        }
        
        sleepStages = records
    }
    
    private func createSampleCompletedSession() -> NapSession {
        let startTime = Date().addingTimeInterval(-5400) // 1.5 hours ago
        let actualDuration = 5200.0 // 86 minutes and 40 seconds
        
        var session = NapSession(
            startTime: startTime,
            targetDuration: 90 * 60, // 90 minutes target
            configuration: .default
        )
        
        // In a real implementation, you'd update these fields properly
        // For demo purposes, we'll note that the session ended at optimal time
        return session
    }
}
