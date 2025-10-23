import Foundation

/// Generates synthetic training data for ML models
public class TrainingDataGenerator {
    
    /// Generates comprehensive training data for nap prediction models
    public static func generateTrainingData(sessionCount: Int) -> [TrainingDataPoint] {
        var trainingData: [TrainingDataPoint] = []
        
        // Generate diverse user profiles
        let userProfiles = generateUserProfiles(count: sessionCount / 10)
        
        for i in 0..<sessionCount {
            let profile = userProfiles[i % userProfiles.count]
            let napSession = generateNapSession(for: profile, sessionIndex: i)
            
            // Generate multiple data points per nap session (every 30 seconds)
            let dataPoints = generateDataPointsForSession(napSession, profile: profile)
            trainingData.append(contentsOf: dataPoints)
        }
        
        print("📊 Generated \(trainingData.count) training data points from \(sessionCount) nap sessions")
        return trainingData
    }
    
    /// Generates diverse user profiles with different characteristics
    private static func generateUserProfiles(count: Int) -> [UserProfile] {
        var profiles: [UserProfile] = []
        
        for i in 0..<count {
            let profile = UserProfile(
                age: Int.random(in: 18...75),
                averageSleepHours: Double.random(in: 5.0...9.0),
                fitnessLevel: FitnessLevel.allCases.randomElement()!,
                napFrequency: NapFrequency.allCases.randomElement()!,
                chronotype: Chronotype.allCases.randomElement()!,
                baseHeartRate: Double.random(in: 50...90),
                baseHRV: Double.random(in: 20...60)
            )
            profiles.append(profile)
        }
        
        return profiles
    }
    
    /// Generates a realistic nap session for a user profile
    private static func generateNapSession(for profile: UserProfile, sessionIndex: Int) -> SyntheticNapSession {
        let timeOfDay = generateRealisticNapTime(for: profile)
        let targetDuration = generateNapDuration(for: profile)
        let sleepDebt = generateSleepDebt(for: profile)
        let caffeineHours = generateCaffeineHours()
        
        return SyntheticNapSession(
            profile: profile,
            timeOfDay: timeOfDay,
            targetDuration: targetDuration,
            sleepDebt: sleepDebt,
            caffeineHours: caffeineHours,
            sessionIndex: sessionIndex
        )
    }
    
    /// Generates data points throughout a nap session (every 30 seconds)
    private static func generateDataPointsForSession(_ session: SyntheticNapSession, profile: UserProfile) -> [TrainingDataPoint] {
        var dataPoints: [TrainingDataPoint] = []
        let samplingInterval: TimeInterval = 30 // 30 seconds
        let totalPoints = Int(session.targetDuration / samplingInterval)
        
        // Simulate sleep stage progression
        let sleepStages = generateSleepStageProgression(duration: session.targetDuration, profile: profile)
        
        for i in 0..<totalPoints {
            let timeInNap = Double(i) * samplingInterval
            let sleepStage = getSleepStageAtTime(timeInNap, stages: sleepStages)
            
            // Generate biometric data based on sleep stage and user profile
            let heartRate = generateHeartRate(for: sleepStage, profile: profile, timeInNap: timeInNap)
            let hrv = generateHRV(for: sleepStage, profile: profile, heartRate: heartRate)
            let motion = generateMotionData(for: sleepStage, timeInNap: timeInNap)
            
            // Determine if this is an optimal wake time
            let isOptimalWakeTime = determineOptimalWakeTime(
                sleepStage: sleepStage,
                timeInNap: timeInNap,
                targetDuration: session.targetDuration,
                sleepStages: sleepStages
            )
            
            let dataPoint = TrainingDataPoint(
                heartRate: heartRate,
                heartRateVariability: hrv,
                motionMagnitude: motion.magnitude,
                motionVariance: motion.variance,
                sleepStage: sleepStage,
                timeInNap: timeInNap,
                napDuration: session.targetDuration,
                userAge: profile.age,
                timeOfDay: session.timeOfDay,
                caffeineHours: session.caffeineHours,
                sleepDebt: session.sleepDebt,
                isOptimalWakeTime: isOptimalWakeTime
            )
            
            dataPoints.append(dataPoint)
        }
        
        return dataPoints
    }
    
    /// Generates realistic sleep stage progression for a nap
    private static func generateSleepStageProgression(duration: TimeInterval, profile: UserProfile) -> [SleepStageSegment] {
        var stages: [SleepStageSegment] = []
        var currentTime: TimeInterval = 0
        
        // Most naps follow: Awake -> Light Sleep -> Deep Sleep -> Light Sleep -> REM (optional)
        
        // Sleep onset (2-10 minutes)
        let onsetDuration = Double.random(in: 120...600) // 2-10 minutes
        stages.append(SleepStageSegment(stage: .awake, startTime: currentTime, duration: onsetDuration))
        currentTime += onsetDuration
        
        // Light sleep phase 1 (5-15 minutes)
        let lightSleep1Duration = min(Double.random(in: 300...900), duration - currentTime - 300)
        if lightSleep1Duration > 0 {
            stages.append(SleepStageSegment(stage: .lightSleep, startTime: currentTime, duration: lightSleep1Duration))
            currentTime += lightSleep1Duration
        }
        
        // Deep sleep (for longer naps, 10-30 minutes)
        if duration > 1200 && currentTime < duration - 600 { // Only for naps > 20 min
            let deepSleepDuration = min(Double.random(in: 600...1800), duration - currentTime - 300)
            stages.append(SleepStageSegment(stage: .deepSleep, startTime: currentTime, duration: deepSleepDuration))
            currentTime += deepSleepDuration
        }
        
        // Light sleep phase 2 (remainder of nap, often wake up here)
        if currentTime < duration {
            let remainingTime = duration - currentTime
            if remainingTime > 120 { // At least 2 minutes
                // 80% chance of light sleep, 20% chance of REM for longer naps
                let finalStage: SleepStage = (duration > 3600 && Double.random(in: 0...1) < 0.2) ? .remSleep : .lightSleep
                stages.append(SleepStageSegment(stage: finalStage, startTime: currentTime, duration: remainingTime))
            }
        }
        
        return stages
    }
    
    /// Gets the sleep stage at a specific time in the nap
    private static func getSleepStageAtTime(_ time: TimeInterval, stages: [SleepStageSegment]) -> SleepStage {
        for stage in stages {
            if time >= stage.startTime && time < stage.startTime + stage.duration {
                return stage.stage
            }
        }
        return .awake // Default fallback
    }
    
    /// Generates realistic heart rate based on sleep stage and user profile
    private static func generateHeartRate(for stage: SleepStage, profile: UserProfile, timeInNap: TimeInterval) -> Double {
        let baseHR = profile.baseHeartRate
        let ageAdjustment = Double(profile.age - 30) * 0.2 // Slight increase with age
        
        let stageMultiplier: Double = switch stage {
        case .awake: 1.0
        case .lightSleep: 0.85
        case .deepSleep: 0.75
        case .remSleep: 0.95
        }
        
        let targetHR = (baseHR + ageAdjustment) * stageMultiplier
        
        // Add realistic variability
        let noise = Double.random(in: -5...5)
        let circadianEffect = sin(timeInNap / 1800) * 2 // Slight oscillation
        
        return max(40, targetHR + noise + circadianEffect)
    }
    
    /// Generates heart rate variability based on sleep stage
    private static func generateHRV(for stage: SleepStage, profile: UserProfile, heartRate: Double) -> Double {
        let baseHRV = profile.baseHRV
        
        let stageMultiplier: Double = switch stage {
        case .awake: 0.8
        case .lightSleep: 1.2
        case .deepSleep: 1.5
        case .remSleep: 1.0
        }
        
        let targetHRV = baseHRV * stageMultiplier
        let noise = Double.random(in: -3...3)
        
        return max(10, targetHRV + noise)
    }
    
    /// Generates motion data based on sleep stage
    private static func generateMotionData(for stage: SleepStage, timeInNap: TimeInterval) -> (magnitude: Double, variance: Double) {
        let baseMagnitude: Double = switch stage {
        case .awake: Double.random(in: 0.8...2.0)
        case .lightSleep: Double.random(in: 0.1...0.4)
        case .deepSleep: Double.random(in: 0.0...0.1)
        case .remSleep: Double.random(in: 0.2...0.6)
        }
        
        let variance: Double = switch stage {
        case .awake: Double.random(in: 0.3...0.8)
        case .lightSleep: Double.random(in: 0.1...0.3)
        case .deepSleep: Double.random(in: 0.0...0.1)
        case .remSleep: Double.random(in: 0.2...0.5)
        }
        
        return (magnitude: baseMagnitude, variance: variance)
    }
    
    /// Determines if current time is optimal for waking up
    private static func determineOptimalWakeTime(
        sleepStage: SleepStage,
        timeInNap: TimeInterval,
        targetDuration: TimeInterval,
        sleepStages: [SleepStageSegment]
    ) -> Bool {
        // Optimal wake times are typically:
        // 1. During light sleep phases
        // 2. At natural sleep cycle boundaries (90-minute intervals)
        // 3. When close to target duration
        
        let timeToTarget = targetDuration - timeInNap
        
        // If very close to target duration (within 5 minutes), it's optimal
        if timeToTarget <= 300 {
            return sleepStage == .lightSleep || sleepStage == .awake
        }
        
        // Check if we're at a sleep cycle boundary (every ~90 minutes)
        let cyclePosition = timeInNap.truncatingRemainder(dividingBy: 5400) // 90 minutes
        let isNearCycleBoundary = cyclePosition < 300 || cyclePosition > 5100 // Within 5 min of boundary
        
        if isNearCycleBoundary && sleepStage == .lightSleep {
            return true
        }
        
        // Generally not optimal to wake during deep sleep
        if sleepStage == .deepSleep {
            return false
        }
        
        return false
    }
    
    /// Generates realistic nap times based on user chronotype
    private static func generateRealisticNapTime(for profile: UserProfile) -> Double {
        let baseTime: Double = switch profile.chronotype {
        case .earlyBird: Double.random(in: 12.5...14.0) // 12:30 PM - 2:00 PM
        case .intermediate: Double.random(in: 13.0...15.0) // 1:00 PM - 3:00 PM
        case .nightOwl: Double.random(in: 14.0...16.0) // 2:00 PM - 4:00 PM
        }
        
        // Add some randomness
        return baseTime + Double.random(in: -0.5...0.5)
    }
    
    /// Generates nap duration based on user habits
    private static func generateNapDuration(for profile: UserProfile) -> TimeInterval {
        let baseDuration: TimeInterval = switch profile.napFrequency {
        case .never: Double.random(in: 600...1200) // 10-20 min (inexperienced)
        case .rarely: Double.random(in: 900...1800) // 15-30 min
        case .sometimes: Double.random(in: 1200...2400) // 20-40 min
        case .regularly: Double.random(in: 1200...3600) // 20-60 min
        case .daily: Double.random(in: 1500...5400) // 25-90 min (power nappers)
        }
        
        return baseDuration
    }
    
    /// Generates sleep debt hours
    private static func generateSleepDebt(for profile: UserProfile) -> Double {
        // Sleep debt typically ranges from 0-4 hours
        return Double.random(in: 0...4)
    }
    
    /// Generates hours since last caffeine consumption
    private static func generateCaffeineHours() -> Double {
        // Realistic caffeine consumption patterns
        let scenarios = [
            0.5,  // Just had coffee
            2.0,  // Recent coffee
            4.0,  // Morning coffee
            8.0,  // Yesterday's coffee
            24.0  // No recent caffeine
        ]
        
        return scenarios.randomElement()!
    }
}

// MARK: - Supporting Types

public struct UserProfile {
    let age: Int
    let averageSleepHours: Double
    let fitnessLevel: FitnessLevel
    let napFrequency: NapFrequency
    let chronotype: Chronotype
    let baseHeartRate: Double
    let baseHRV: Double
}

public enum FitnessLevel: CaseIterable {
    case low, moderate, high, athlete
}

public enum NapFrequency: CaseIterable {
    case never, rarely, sometimes, regularly, daily
}

public enum Chronotype: CaseIterable {
    case earlyBird, intermediate, nightOwl
}

public struct SyntheticNapSession {
    let profile: UserProfile
    let timeOfDay: Double
    let targetDuration: TimeInterval
    let sleepDebt: Double
    let caffeineHours: Double
    let sessionIndex: Int
}

public struct SleepStageSegment {
    let stage: SleepStage
    let startTime: TimeInterval
    let duration: TimeInterval
}

public struct TrainingDataPoint {
    let heartRate: Double
    let heartRateVariability: Double
    let motionMagnitude: Double
    let motionVariance: Double
    let sleepStage: SleepStage
    let timeInNap: TimeInterval
    let napDuration: TimeInterval
    let userAge: Int
    let timeOfDay: Double
    let caffeineHours: Double
    let sleepDebt: Double
    let isOptimalWakeTime: Bool
}
