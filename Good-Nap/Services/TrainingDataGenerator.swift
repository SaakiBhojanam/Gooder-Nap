import Foundation

/// Generates synthetic training data for ML model training
public class TrainingDataGenerator {
    
    public static func generateTrainingData(count: Int = 2000) -> [NapSession] {
        var sessions: [NapSession] = []
        let calendar = Calendar.current
        let now = Date()
        
        // User profiles for diversity
        let userProfiles = [
            (age: 25, chronotype: "morning", fitnessLevel: 0.8, napFrequency: 0.3),
            (age: 35, chronotype: "evening", fitnessLevel: 0.6, napFrequency: 0.7),
            (age: 45, chronotype: "neutral", fitnessLevel: 0.7, napFrequency: 0.5),
            (age: 28, chronotype: "morning", fitnessLevel: 0.9, napFrequency: 0.2),
            (age: 52, chronotype: "evening", fitnessLevel: 0.5, napFrequency: 0.8)
        ]
        
        for i in 0..<count {
            let profile = userProfiles[i % userProfiles.count]
            let startTime = calendar.date(byAdding: .day, value: -Int.random(in: 1...365), to: now)!
            let napDuration = TimeInterval(Int.random(in: 10...90) * 60) // 10-90 minutes
            let endTime = startTime.addingTimeInterval(napDuration)
            
            // Generate configuration
            let config = NapConfiguration(
                maxDuration: napDuration + TimeInterval(Int.random(in: 0...600)), // Buffer time
                preferredWakeTime: nil,
                enableSmartWake: Bool.random(),
                wakeWindowMinutes: Int.random(in: 5...15),
                hapticIntensity: Double.random(in: 0.3...1.0)
            )
            
            // Generate biometric data points (every 30 seconds)
            var biometricData: [BiometricDataPoint] = []
            var sleepStages: [SleepStageRecord] = []
            
            let dataPointInterval: TimeInterval = 30
            let totalDataPoints = Int(napDuration / dataPointInterval)
            
            // Sleep stage progression: Awake -> Light -> Deep -> Light/REM -> Awake
            let stageProgression = generateSleepStageProgression(duration: napDuration, profile: profile)
            
            for j in 0..<totalDataPoints {
                let timestamp = startTime.addingTimeInterval(Double(j) * dataPointInterval)
                let progressRatio = Double(j) / Double(totalDataPoints)
                
                // Get current sleep stage
                let currentStage = stageProgression[min(j, stageProgression.count - 1)]
                
                // Generate biometric data based on sleep stage and user profile
                let biometrics = generateBiometricData(
                    for: currentStage,
                    timestamp: timestamp,
                    progressRatio: progressRatio,
                    profile: profile
                )
                biometricData.append(biometrics)
                
                // Add sleep stage record every 2 minutes
                if j % 4 == 0 {
                    let confidence = Double.random(in: 0.75...0.95)
                    let duration = min(dataPointInterval * 4, napDuration - Double(j) * dataPointInterval)
                    
                    let stageRecord = SleepStageRecord(
                        timestamp: timestamp,
                        stage: currentStage,
                        confidence: confidence,
                        duration: duration
                    )
                    sleepStages.append(stageRecord)
                }
            }
            
            // Calculate optimal wake time (during light sleep or awake phases)
            let optimalWakeTime = findOptimalWakeTime(sleepStages: sleepStages, startTime: startTime, duration: napDuration)
            
            // Generate user rating based on wake time alignment
            let userRating = generateUserRating(
                optimalWakeTime: optimalWakeTime,
                actualWakeTime: endTime,
                napDuration: napDuration
            )
            
            let session = NapSession(
                startTime: startTime,
                endTime: endTime,
                configuration: config,
                biometricData: biometricData,
                sleepStages: sleepStages,
                optimalWakeTime: optimalWakeTime,
                actualWakeTime: endTime,
                userRating: userRating,
                notes: generateRandomNotes()
            )
            
            sessions.append(session)
        }
        
        return sessions
    }
    
    private static func generateSleepStageProgression(duration: TimeInterval, profile: (age: Int, chronotype: String, fitnessLevel: Double, napFrequency: Double)) -> [SleepStage] {
        let dataPointInterval: TimeInterval = 30
        let totalDataPoints = Int(duration / dataPointInterval)
        var stages: [SleepStage] = []
        
        // Typical nap progression
        let awakeDuration = Int(Double(totalDataPoints) * 0.1) // 10% awake at start
        let lightSleepDuration = Int(Double(totalDataPoints) * 0.4) // 40% light sleep
        let deepSleepDuration = Int(Double(totalDataPoints) * 0.3) // 30% deep sleep
        let remDuration = Int(Double(totalDataPoints) * 0.15) // 15% REM sleep
        let finalAwakeDuration = totalDataPoints - awakeDuration - lightSleepDuration - deepSleepDuration - remDuration
        
        // Add stages with some randomness
        stages += Array(repeating: SleepStage.awake, count: awakeDuration)
        stages += Array(repeating: SleepStage.lightSleep, count: lightSleepDuration)
        stages += Array(repeating: SleepStage.deepSleep, count: deepSleepDuration)
        stages += Array(repeating: SleepStage.remSleep, count: remDuration)
        stages += Array(repeating: SleepStage.lightSleep, count: finalAwakeDuration)
        
        // Add some natural variation
        for i in 0..<stages.count {
            if Double.random(in: 0...1) < 0.1 { // 10% chance of stage variation
                if i > 0 && i < stages.count - 1 {
                    stages[i] = stages[i - 1] // Smooth transitions
                }
            }
        }
        
        return stages
    }
    
    private static func generateBiometricData(
        for stage: SleepStage,
        timestamp: Date,
        progressRatio: Double,
        profile: (age: Int, chronotype: String, fitnessLevel: Double, napFrequency: Double)
    ) -> BiometricDataPoint {
        
        // Base values influenced by user profile
        let baseHR = 60.0 + (40.0 - Double(profile.age - 20) * 0.5) * profile.fitnessLevel
        let baseHRV = 30.0 + (profile.fitnessLevel * 20.0)
        
        var heartRate: Double
        var hrv: Double
        var motion: Double
        
        switch stage {
        case .awake:
            heartRate = baseHR + Double.random(in: 10...20)
            hrv = baseHRV * Double.random(in: 0.6...0.8)
            motion = Double.random(in: 0.3...1.0)
            
        case .lightSleep:
            heartRate = baseHR + Double.random(in: -5...5)
            hrv = baseHRV * Double.random(in: 0.8...1.2)
            motion = Double.random(in: 0.0...0.3)
            
        case .deepSleep:
            heartRate = baseHR + Double.random(in: -15...(-5))
            hrv = baseHRV * Double.random(in: 1.2...1.8)
            motion = Double.random(in: 0.0...0.1)
            
        case .remSleep:
            heartRate = baseHR + Double.random(in: 5...15)
            hrv = baseHRV * Double.random(in: 0.7...1.1)
            motion = Double.random(in: 0.1...0.4)
            
        case .unknown:
            heartRate = baseHR
            hrv = baseHRV
            motion = Double.random(in: 0.0...0.5)
        }
        
        // Add some natural variation
        heartRate += Double.random(in: -3...3)
        hrv += Double.random(in: -5...5)
        motion = max(0, motion + Double.random(in: -0.1...0.1))
        
        return BiometricDataPoint(
            timestamp: timestamp,
            heartRate: max(40, min(120, heartRate)),
            heartRateVariability: max(10, min(100, hrv)),
            motionLevel: max(0, min(1, motion)),
            respiratoryRate: Double.random(in: 12...20),
            oxygenSaturation: Double.random(in: 95...100)
        )
    }
    
    private static func findOptimalWakeTime(sleepStages: [SleepStageRecord], startTime: Date, duration: TimeInterval) -> Date? {
        let endTime = startTime.addingTimeInterval(duration)
        let wakeWindow = TimeInterval(10 * 60) // 10-minute wake window before end
        let wakeWindowStart = endTime.addingTimeInterval(-wakeWindow)
        
        // Find light sleep or awake stages in the wake window
        let candidateStages = sleepStages.filter { stage in
            stage.timestamp >= wakeWindowStart && stage.timestamp <= endTime &&
            (stage.stage == .lightSleep || stage.stage == .awake)
        }
        
        return candidateStages.first?.timestamp ?? endTime.addingTimeInterval(-TimeInterval(Int.random(in: 60...300)))
    }
    
    private static func generateUserRating(optimalWakeTime: Date?, actualWakeTime: Date, napDuration: TimeInterval) -> Int {
        guard let optimalTime = optimalWakeTime else {
            return Int.random(in: 2...4) // Neutral rating if no optimal time
        }
        
        let timeDifference = abs(actualWakeTime.timeIntervalSince(optimalTime))
        
        if timeDifference < 120 { // Within 2 minutes
            return Int.random(in: 4...5)
        } else if timeDifference < 300 { // Within 5 minutes
            return Int.random(in: 3...4)
        } else if timeDifference < 600 { // Within 10 minutes
            return Int.random(in: 2...3)
        } else {
            return Int.random(in: 1...2)
        }
    }
    
    private static func generateRandomNotes() -> String? {
        let notes = [
            "Felt refreshed after this nap",
            "Was a bit groggy when I woke up",
            "Perfect timing, felt great",
            "Woke up naturally during light sleep",
            "Could have used a few more minutes",
            nil, nil, nil // 50% chance of no notes
        ]
        return notes.randomElement()!
    }
}
