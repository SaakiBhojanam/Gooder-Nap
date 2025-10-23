import Foundation
import CreateML
import CoreML
import NapSyncShared

/// Trains machine learning models for sleep stage classification and optimal wake time prediction
class MLModelTrainer {
    
    /// Trains both sleep stage and optimal wake time models
    static func trainModels() async throws -> (sleepStageModel: MLModel, optimalWakeModel: MLModel) {
        print("🧠 Generating training data...")
        let trainingData = TrainingDataGenerator.generateTrainingData(sessionCount: 2000)
        
        print("📊 Generated \(trainingData.count) training samples")
        print("🔬 Training sleep stage classification model...")
        let sleepModel = try await trainSleepStageModel(data: trainingData)
        
        print("⏰ Training optimal wake time prediction model...")
        let wakeModel = try await trainOptimalWakeTimeModel(data: trainingData)
        
        print("✅ Models trained successfully!")
        return (sleepModel, wakeModel)
    }
    
    /// Trains a sleep stage classification model using random forest
    private static func trainSleepStageModel(data: [TrainingDataPoint]) async throws -> MLModel {
        // Convert to CreateML table format
        let table = try MLDataTable(dictionary: [
            "heartRate": data.map { $0.heartRate },
            "hrv": data.map { $0.heartRateVariability },
            "motion": data.map { $0.motionMagnitude },
            "motionVariance": data.map { $0.motionVariance },
            "timeInNap": data.map { $0.timeInNap / 60.0 }, // Convert to minutes
            "userAge": data.map { Double($0.userAge) },
            "napDuration": data.map { $0.napDuration / 60.0 }, // Convert to minutes
            "timeOfDay": data.map { $0.timeOfDay },
            "caffeineHours": data.map { $0.caffeineHours },
            "sleepDebt": data.map { $0.sleepDebt },
            "sleepStage": data.map { $0.sleepStage.rawValue }
        ])
        
        // Split data for training and validation
        let (trainingTable, validationTable) = table.randomSplit(by: 0.8)
        
        // Train random forest classifier with optimized parameters
        let classifier = try MLRandomForestClassifier(
            trainingData: trainingTable,
            targetColumn: "sleepStage",
            featureColumns: [
                "heartRate", "hrv", "motion", "motionVariance",
                "timeInNap", "userAge", "napDuration", "timeOfDay",
                "caffeineHours", "sleepDebt"
            ],
            maxDepth: 10,
            numTrees: 50,
            minChildWeight: 5
        )
        
        // Evaluate model performance
        let predictions = try classifier.predictions(from: validationTable)
        let evaluationMetrics = classifier.evaluation(on: validationTable)
        print("🎯 Sleep Stage Model Accuracy: \(evaluationMetrics.classificationError)")
        
        // Save model
        try classifier.write(to: URL(fileURLWithPath: "/tmp/SleepStageClassifier.mlmodel"))
        
        return classifier.model
    }
    
    /// Trains an optimal wake time prediction model
    private static func trainOptimalWakeTimeModel(data: [TrainingDataPoint]) async throws -> MLModel {
        // Convert to CreateML table format for binary classification
        let table = try MLDataTable(dictionary: [
            "heartRate": data.map { $0.heartRate },
            "hrv": data.map { $0.heartRateVariability },
            "motion": data.map { $0.motionMagnitude },
            "motionVariance": data.map { $0.motionVariance },
            "timeInNap": data.map { $0.timeInNap / 60.0 },
            "userAge": data.map { Double($0.userAge) },
            "napDuration": data.map { $0.napDuration / 60.0 },
            "timeOfDay": data.map { $0.timeOfDay },
            "caffeineHours": data.map { $0.caffeineHours },
            "sleepDebt": data.map { $0.sleepDebt },
            "timeRemaining": data.map { ($0.napDuration - $0.timeInNap) / 60.0 },
            "sleepStage": data.map { $0.sleepStage.rawValue },
            "isOptimalWakeTime": data.map { $0.isOptimalWakeTime }
        ])
        
        let (trainingTable, validationTable) = table.randomSplit(by: 0.8)
        
        // Train gradient boosting classifier for optimal wake time prediction
        let classifier = try MLBoostedTreeClassifier(
            trainingData: trainingTable,
            targetColumn: "isOptimalWakeTime",
            featureColumns: [
                "heartRate", "hrv", "motion", "motionVariance",
                "timeInNap", "userAge", "napDuration", "timeOfDay",
                "caffeineHours", "sleepDebt", "timeRemaining", "sleepStage"
            ],
            maxIterations: 100,
            maxDepth: 8,
            minChildWeight: 10
        )
        
        // Evaluate model
        let evaluationMetrics = classifier.evaluation(on: validationTable)
        print("⏰ Optimal Wake Time Model Accuracy: \(evaluationMetrics.classificationError)")
        
        // Save model
        try classifier.write(to: URL(fileURLWithPath: "/tmp/OptimalWakeTimeClassifier.mlmodel"))
        
        return classifier.model
    }
    
    /// Generates additional personalized training data based on user feedback
    static func generatePersonalizedData(
        userFeedback: [NapFeedback],
        baseProfile: UserProfile
    ) -> [TrainingDataPoint] {
        var personalizedData: [TrainingDataPoint] = []
        
        for feedback in userFeedback {
            // Generate additional training points based on user's reported experience
            let adjustmentFactor = calculateAdjustmentFactor(feedback: feedback)
            
            // Create variations around the original session data
            for _ in 0..<10 { // Generate 10 variations per feedback
                let adjustedPoint = createAdjustedTrainingPoint(
                    originalFeedback: feedback,
                    adjustmentFactor: adjustmentFactor,
                    userProfile: baseProfile
                )
                personalizedData.append(adjustedPoint)
            }
        }
        
        return personalizedData
    }
    
    /// Calculates how much to adjust the model based on user feedback
    private static func calculateAdjustmentFactor(feedback: NapFeedback) -> Double {
        // Convert feedback into adjustment factor
        let qualityScore = Double(feedback.qualityRating) / 5.0 // Normalize to 0-1
        let feelingScore = feedback.postNapFeeling.score // Custom score based on feeling
        
        // Combined score: higher means user was satisfied with wake time
        let combinedScore = (qualityScore + feelingScore) / 2.0
        
        // Return adjustment factor: positive means reinforce this pattern, negative means avoid
        return (combinedScore - 0.5) * 2.0 // Scale to -1 to 1
    }
    
    /// Creates adjusted training points based on user feedback
    private static func createAdjustedTrainingPoint(
        originalFeedback: NapFeedback,
        adjustmentFactor: Double,
        userProfile: UserProfile
    ) -> TrainingDataPoint {
        // Base the new point on the original session but with adjustments
        let session = originalFeedback.napSession
        
        // If user was satisfied (positive adjustment), mark similar conditions as optimal
        // If user was dissatisfied (negative adjustment), mark as non-optimal
        let shouldBeOptimal = adjustmentFactor > 0
        
        // Generate biometric data similar to what led to this feedback
        let biometrics = generateSimilarBiometrics(
            to: originalFeedback.sessionBiometrics,
            adjustment: adjustmentFactor
        )
        
        return TrainingDataPoint(
            sessionId: "personalized_\(session.id)",
            timeInNap: session.duration * 0.9, // Near end of nap
            heartRate: biometrics.heartRate,
            heartRateVariability: biometrics.hrv,
            motionMagnitude: biometrics.motion,
            motionVariance: biometrics.motionVariance,
            sleepStage: inferSleepStageFromBiometrics(biometrics),
            isOptimalWakeTime: shouldBeOptimal,
            userAge: userProfile.age,
            userWeight: userProfile.weight,
            napDuration: session.duration,
            timeOfDay: Calendar.current.component(.hour, from: session.startTime),
            caffeineHours: Double.random(in: 2...8), // Estimate
            sleepDebt: Double.random(in: 0...3) // Estimate
        )
    }
    
    private static func generateSimilarBiometrics(
        to original: [BiometricDataPoint],
        adjustment: Double
    ) -> BiometricData {
        guard let lastPoint = original.last else {
            return BiometricData(heartRate: 65, hrv: 40, motion: 0.1, motionVariance: 0.01)
        }
        
        // Adjust biometrics slightly based on feedback
        let variance = abs(adjustment) * 0.1 // Small variations
        
        return BiometricData(
            heartRate: (lastPoint.heartRate ?? 65) + Double.random(in: -variance...variance) * 10,
            hrv: (lastPoint.heartRateVariability ?? 40) + Double.random(in: -variance...variance) * 5,
            motion: (lastPoint.motionMagnitude ?? 0.1) + Double.random(in: -variance...variance),
            motionVariance: pow((lastPoint.motionMagnitude ?? 0.1) + Double.random(in: -variance...variance), 2)
        )
    }
    
    private static func inferSleepStageFromBiometrics(_ biometrics: BiometricData) -> SleepStage {
        if biometrics.motion > 0.5 { return .awake }
        if biometrics.motion < 0.1 && biometrics.hrv > 50 { return .deepSleep }
        if biometrics.heartRate > 70 { return .rem }
        return .lightSleep
    }
}

// MARK: - Supporting Types

struct NapFeedback {
    let napSession: NapSession
    let qualityRating: Int // 1-5 stars
    let postNapFeeling: PostNapFeeling
    let sessionBiometrics: [BiometricDataPoint]
    let wasWakeTimeOptimal: Bool
    let timestamp: Date
}

extension PostNapFeeling {
    var score: Double {
        switch self {
        case .refreshed: return 1.0
        case .alert: return 0.8
        case .tired: return 0.3
        case .groggy: return 0.1
        }
    }
}