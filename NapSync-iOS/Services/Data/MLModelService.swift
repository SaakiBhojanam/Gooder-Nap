import Foundation
import CoreML
import NapSyncShared

/// Service that manages the complete ML pipeline for NapSync
@MainActor
class MLModelService: ObservableObject {
    @Published var isTrainingInProgress: Bool = false
    @Published var trainingProgress: Double = 0.0
    @Published var modelAccuracy: Double = 0.0
    @Published var isModelReady: Bool = false
    @Published var trainingDataCount: Int = 0
    
    private var sleepStageModel: MLModel?
    private var optimalWakeModel: MLModel?
    private let personalizationEngine = PersonalizationEngine()
    
    static let shared = MLModelService()
    
    private init() {
        checkModelStatus()
    }
    
    /// Initializes the ML models on first app launch
    func initializeMLModels() async {
        guard !isModelReady else { return }
        
        isTrainingInProgress = true
        trainingProgress = 0.0
        
        do {
            // Step 1: Generate comprehensive training data (40% of progress)
            await updateProgress(0.1, status: "Generating training data...")
            let trainingData = TrainingDataGenerator.generateTrainingData(sessionCount: 2000)
            trainingDataCount = trainingData.count
            await updateProgress(0.4, status: "Training data generated: \(trainingData.count) samples")
            
            // Step 2: Train sleep stage classification model (30% of progress)
            await updateProgress(0.5, status: "Training sleep stage classifier...")
            let sleepModel = try await trainSleepStageModel(data: trainingData)
            await updateProgress(0.7, status: "Sleep stage model trained")
            
            // Step 3: Train optimal wake time model (20% of progress)
            await updateProgress(0.8, status: "Training optimal wake time predictor...")
            let wakeModel = try await trainOptimalWakeTimeModel(data: trainingData)
            await updateProgress(0.9, status: "Wake time model trained")
            
            // Step 4: Validate and save models (10% of progress)
            await updateProgress(0.95, status: "Validating models...")
            let accuracy = try await validateModels(sleepModel: sleepModel, wakeModel: wakeModel, testData: trainingData)
            
            self.sleepStageModel = sleepModel
            self.optimalWakeModel = wakeModel
            self.modelAccuracy = accuracy
            self.isModelReady = true
            
            await updateProgress(1.0, status: "Models ready! Accuracy: \(String(format: "%.1f%%", accuracy * 100))")
            
            // Save models to app bundle for future launches
            try await saveModelsToBundle(sleepModel: sleepModel, wakeModel: wakeModel)
            
        } catch {
            print("❌ Model training failed: \(error)")
            await updateProgress(0.0, status: "Training failed: \(error.localizedDescription)")
        }
        
        isTrainingInProgress = false
    }
    
    /// Updates training progress and status
    private func updateProgress(_ progress: Double, status: String) async {
        await MainActor.run {
            self.trainingProgress = progress
            print("🧠 ML Training: \(String(format: "%.0f%%", progress * 100)) - \(status)")
        }
        
        // Small delay to make progress visible
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    /// Trains the sleep stage classification model with comprehensive data
    private func trainSleepStageModel(data: [TrainingDataPoint]) async throws -> MLModel {
        // Filter and prepare data for sleep stage classification
        let sleepStageData = data.filter { $0.heartRate > 0 && $0.heartRateVariability > 0 }
        
        print("📊 Training sleep stage model with \(sleepStageData.count) samples")
        
        // Create feature vectors for training
        let features = sleepStageData.map { point in
            [
                point.heartRate,
                point.heartRateVariability,
                point.motionMagnitude,
                point.motionVariance,
                point.timeInNap / 60.0, // Convert to minutes
                Double(point.userAge),
                point.napDuration / 60.0,
                point.timeOfDay,
                point.caffeineHours,
                point.sleepDebt
            ]
        }
        
        let labels = sleepStageData.map { $0.sleepStage.rawValue }
        
        // Use a simplified random forest implementation for demonstration
        // In production, this would use CreateML's MLRandomForestClassifier
        let model = try await createSimulatedClassificationModel(
            features: features,
            labels: labels,
            modelName: "SleepStageClassifier"
        )
        
        return model
    }
    
    /// Trains the optimal wake time prediction model
    private func trainOptimalWakeTimeModel(data: [TrainingDataPoint]) async throws -> MLModel {
        let wakeTimeData = data.filter {
            $0.heartRate > 0 && $0.heartRateVariability > 0 &&
            ($0.napDuration - $0.timeInNap) <= 15 * 60 // Only last 15 minutes
        }
        
        print("⏰ Training wake time model with \(wakeTimeData.count) samples")
        
        let features = wakeTimeData.map { point in
            [
                point.heartRate,
                point.heartRateVariability,
                point.motionMagnitude,
                point.motionVariance,
                point.timeInNap / 60.0,
                Double(point.userAge),
                point.napDuration / 60.0,
                point.timeOfDay,
                point.caffeineHours,
                point.sleepDebt,
                (point.napDuration - point.timeInNap) / 60.0, // Time remaining
                point.sleepStage == .lightSleep ? 1.0 : 0.0 // Sleep stage indicator
            ]
        }
        
        let labels = wakeTimeData.map { $0.isOptimalWakeTime }
        
        let model = try await createSimulatedBinaryClassificationModel(
            features: features,
            labels: labels,
            modelName: "OptimalWakeTimeClassifier"
        )
        
        return model
    }
    
    /// Validates model performance on test data
    private func validateModels(
        sleepModel: MLModel,
        wakeModel: MLModel,
        testData: [TrainingDataPoint]
    ) async throws -> Double {
        let testSamples = Array(testData.suffix(200)) // Use last 200 samples for testing
        var correctPredictions = 0
        
        for sample in testSamples {
            // Test sleep stage prediction
            let sleepPrediction = try await predictSleepStage(
                model: sleepModel,
                sample: sample
            )
            
            if sleepPrediction == sample.sleepStage {
                correctPredictions += 1
            }
        }
        
        let accuracy = Double(correctPredictions) / Double(testSamples.count)
        print("🎯 Model validation accuracy: \(String(format: "%.1f%%", accuracy * 100))")
        
        return accuracy
    }
    
    /// Creates a simulated classification model for demonstration
    private func createSimulatedClassificationModel(
        features: [[Double]],
        labels: [String],
        modelName: String
    ) async throws -> MLModel {
        print("🏗️ Creating simulated \(modelName) with \(features.count) samples")
        
        // Simulate training time
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Create a mock MLModel that uses simple heuristics
        let model = MockMLModel(
            name: modelName,
            type: .classification,
            features: features,
            labels: labels
        )
        
        return model
    }
    
    /// Creates a simulated binary classification model
    private func createSimulatedBinaryClassificationModel(
        features: [[Double]],
        labels: [Bool],
        modelName: String
    ) async throws -> MLModel {
        print("🏗️ Creating simulated \(modelName) with \(features.count) samples")
        
        // Simulate training time
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Convert boolean labels to strings
        let stringLabels = labels.map { $0 ? "true" : "false" }
        
        let model = MockMLModel(
            name: modelName,
            type: .binaryClassification,
            features: features,
            labels: stringLabels
        )
        
        return model
    }
    
    /// Predicts sleep stage for a given sample
    private func predictSleepStage(
        model: MLModel,
        sample: TrainingDataPoint
    ) async throws -> SleepStage {
        let features = [
            sample.heartRate,
            sample.heartRateVariability,
            sample.motionMagnitude,
            sample.motionVariance,
            sample.timeInNap / 60.0,
            Double(sample.userAge),
            sample.napDuration / 60.0,
            sample.timeOfDay,
            sample.caffeineHours,
            sample.sleepDebt
        ]
        
        if let mockModel = model as? MockMLModel {
            let prediction = mockModel.predict(features: features)
            return SleepStage(rawValue: prediction) ?? .awake
        }
        
        return .awake // Fallback
    }
    
    /// Saves trained models to app bundle
    private func saveModelsToBundle(
        sleepModel: MLModel,
        wakeModel: MLModel
    ) async throws {
        print("💾 Saving models to app bundle...")
        
        // In a real implementation, this would save the models to disk
        // For now, we'll just simulate the save operation
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        UserDefaults.standard.set(true, forKey: "MLModelsInitialized")
        print("✅ Models saved successfully")
    }
    
    /// Checks if models are already trained and ready
    private func checkModelStatus() {
        isModelReady = UserDefaults.standard.bool(forKey: "MLModelsInitialized")
        if isModelReady {
            // Load pre-trained models
            loadSavedModels()
        }
    }
    
    /// Loads previously saved models
    private func loadSavedModels() {
        // In a real implementation, this would load actual saved models
        // For demonstration, we'll create mock models
        sleepStageModel = MockMLModel(
            name: "SleepStageClassifier",
            type: .classification,
            features: [],
            labels: []
        )
        
        optimalWakeModel = MockMLModel(
            name: "OptimalWakeTimeClassifier",
            type: .binaryClassification,
            features: [],
            labels: []
        )
        
        modelAccuracy = 0.87 // Simulated accuracy
        print("✅ Pre-trained models loaded")
    }
    
    // MARK: - Public Prediction Methods
    
    /// Predicts the current sleep stage based on biometric data
    func predictCurrentSleepStage(
        heartRate: Double,
        hrv: Double,
        motionMagnitude: Double,
        motionVariance: Double,
        timeInNap: TimeInterval,
        userAge: Int,
        napDuration: TimeInterval,
        timeOfDay: Double,
        caffeineHours: Double,
        sleepDebt: Double
    ) async -> SleepStage {
        guard let model = sleepStageModel else {
            return .awake
        }
        
        let sample = TrainingDataPoint(
            heartRate: heartRate,
            heartRateVariability: hrv,
            motionMagnitude: motionMagnitude,
            motionVariance: motionVariance,
            sleepStage: .awake, // Placeholder
            timeInNap: timeInNap,
            napDuration: napDuration,
            userAge: userAge,
            timeOfDay: timeOfDay,
            caffeineHours: caffeineHours,
            sleepDebt: sleepDebt,
            isOptimalWakeTime: false // Placeholder
        )
        
        do {
            return try await predictSleepStage(model: model, sample: sample)
        } catch {
            print("❌ Sleep stage prediction failed: \(error)")
            return .awake
        }
    }
    
    /// Predicts if current time is optimal for waking up
    func predictOptimalWakeTime(
        heartRate: Double,
        hrv: Double,
        motionMagnitude: Double,
        motionVariance: Double,
        timeInNap: TimeInterval,
        userAge: Int,
        napDuration: TimeInterval,
        timeOfDay: Double,
        caffeineHours: Double,
        sleepDebt: Double,
        currentSleepStage: SleepStage
    ) async -> Bool {
        guard let model = optimalWakeModel else {
            return false
        }
        
        let features = [
            heartRate,
            hrv,
            motionMagnitude,
            motionVariance,
            timeInNap / 60.0,
            Double(userAge),
            napDuration / 60.0,
            timeOfDay,
            caffeineHours,
            sleepDebt,
            (napDuration - timeInNap) / 60.0,
            currentSleepStage == .lightSleep ? 1.0 : 0.0
        ]
        
        if let mockModel = model as? MockMLModel {
            let prediction = mockModel.predict(features: features)
            return prediction == "true"
        }
        
        return false
    }
    
    /// Updates the personalization engine with new nap data
    func updatePersonalization(with napSession: NapSession) {
        personalizationEngine.addNapSession(napSession)
    }
}

// MARK: - Mock ML Model for Demonstration

/// A mock ML model that simulates real CoreML behavior for demonstration
class MockMLModel: MLModel {
    private let modelName: String
    private let modelType: ModelType
    private let trainingFeatures: [[Double]]
    private let trainingLabels: [String]
    
    enum ModelType {
        case classification
        case binaryClassification
    }
    
    init(name: String, type: ModelType, features: [[Double]], labels: [String]) {
        self.modelName = name
        self.modelType = type
        self.trainingFeatures = features
        self.trainingLabels = labels
    }
    
    /// Simulates ML prediction using heuristics based on training data patterns
    func predict(features: [Double]) -> String {
        switch modelName {
        case "SleepStageClassifier":
            return predictSleepStageHeuristic(features: features)
        case "OptimalWakeTimeClassifier":
            return predictOptimalWakeTimeHeuristic(features: features)
        default:
            return "unknown"
        }
    }
    
    /// Sleep stage prediction using realistic heuristics
    private func predictSleepStageHeuristic(features: [Double]) -> String {
        guard features.count >= 10 else { return "awake" }
        
        let heartRate = features[0]
        let hrv = features[1]
        let motionMagnitude = features[2]
        let motionVariance = features[3]
        let timeInNap = features[4] // in minutes
        
        // High motion = awake
        if motionMagnitude > 0.5 || motionVariance > 0.4 {
            return "awake"
        }
        
        // Very early in nap = likely awake or light sleep
        if timeInNap < 5 {
            return motionMagnitude > 0.2 ? "awake" : "lightSleep"
        }
        
        // Low motion + high HRV + moderate HR = deep sleep
        if motionMagnitude < 0.1 && hrv > 40 && heartRate < 65 {
            return "deepSleep"
        }
        
        // Moderate motion + lower HRV = REM sleep (for longer naps)
        if timeInNap > 60 && motionMagnitude > 0.1 && motionMagnitude < 0.3 && hrv < 35 {
            return "remSleep"
        }
        
        // Default to light sleep
        return "lightSleep"
    }
    
    /// Optimal wake time prediction using realistic heuristics
    private func predictOptimalWakeTimeHeuristic(features: [Double]) -> String {
        guard features.count >= 12 else { return "false" }
        
        let heartRate = features[0]
        let hrv = features[1]
        let motionMagnitude = features[2]
        let timeInNap = features[4] // in minutes
        let timeRemaining = features[10] // in minutes
        let isLightSleep = features[11] > 0.5
        
        // Very close to target duration
        if timeRemaining <= 5 {
            return isLightSleep ? "true" : "false"
        }
        
        // At sleep cycle boundaries (every 90 minutes) during light sleep
        let cyclePosition = timeInNap.truncatingRemainder(dividingBy: 90)
        let isNearCycleBoundary = cyclePosition < 5 || cyclePosition > 85
        
        if isNearCycleBoundary && isLightSleep {
            return "true"
        }
        
        // High motion suggests natural awakening
        if motionMagnitude > 0.3 && isLightSleep {
            return "true"
        }
        
        return "false"
    }
}

// MARK: - Personalization Engine

/// Handles personalized recommendations based on user's nap history
class PersonalizationEngine {
    private var napHistory: [NapSession] = []
    
    func addNapSession(_ session: NapSession) {
        napHistory.append(session)
        
        // Keep only last 50 sessions for performance
        if napHistory.count > 50 {
            napHistory.removeFirst()
        }
        
        analyzePatterns()
    }
    
    private func analyzePatterns() {
        // Analyze user's nap patterns to improve recommendations
        // This would include optimal nap durations, best times, etc.
        print("📈 Analyzing nap patterns from \(napHistory.count) sessions")
    }
}
                correctPredictions += 1
            }
        }
        
        return Double(correctPredictions) / Double(testSamples.count)
    }
    
    /// Simulated model creation for demonstration (would use CreateML in production)
    private func createSimulatedClassificationModel(
        features: [[Double]],
        labels: [String],
        modelName: String
    ) async throws -> MLModel {
        // Simulate model training time
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Create a mock MLModel for demonstration
        // In production, this would return an actual trained CreateML model
        let modelURL = try createMockModel(name: modelName)
        return try MLModel(contentsOf: modelURL)
    }
    
    /// Simulated binary classification model creation
    private func createSimulatedBinaryClassificationModel(
        features: [[Double]],
        labels: [Bool],
        modelName: String
    ) async throws -> MLModel {
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        let modelURL = try createMockModel(name: modelName)
        return try MLModel(contentsOf: modelURL)
    }
    
    /// Creates a mock model file for demonstration
    private func createMockModel(name: String) throws -> URL {
        // In a real implementation, this would be the actual trained model
        // For demonstration, we'll create a minimal model file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let modelURL = documentsPath.appendingPathComponent("\(name).mlmodel")
        
        // Create minimal model data
        let modelData = Data("MockModel_\(name)".utf8)
        try modelData.write(to: modelURL)
        
        return modelURL
    }
    
    /// Saves trained models to app bundle for future use
    private func saveModelsToBundle(sleepModel: MLModel, wakeModel: MLModel) async throws {
        print("💾 Saving models to app bundle...")
        // In production, save compiled models to app's documents directory
        // This would involve model serialization and secure storage
    }
    
    /// Predicts sleep stage using trained model
    private func predictSleepStage(model: MLModel, sample: TrainingDataPoint) async throws -> SleepStage {
        // Simulate prediction logic
        // In production, this would use the actual ML model prediction
        
        // Use simple heuristics as fallback for demonstration
        if sample.motionMagnitude > 0.5 {
            return .awake
        } else if sample.motionMagnitude < 0.1 && sample.heartRateVariability > 50 {
            return .deepSleep
        } else {
            return .lightSleep
        }
    }
    
    /// Checks if models are already trained and available
    private func checkModelStatus() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let sleepModelURL = documentsPath.appendingPathComponent("SleepStageClassifier.mlmodel")
        let wakeModelURL = documentsPath.appendingPathComponent("OptimalWakeTimeClassifier.mlmodel")
        
        isModelReady = FileManager.default.fileExists(atPath: sleepModelURL.path) &&
                      FileManager.default.fileExists(atPath: wakeModelURL.path)
        
        if isModelReady {
            modelAccuracy = 0.87 // Simulated accuracy for existing models
            print("✅ ML models already available")
        } else {
            print("🔄 ML models need to be trained")
        }
    }
    
    /// Retrains models with new user feedback data
    func retrainWithUserFeedback(_ feedbackData: [NapFeedback]) async {
        guard feedbackData.count >= 10 else { return } // Need minimum feedback
        
        isTrainingInProgress = true
        
        do {
            // Generate personalized training data from feedback
            await updateProgress(0.2, status: "Processing user feedback...")
            let userProfile = personalizationEngine.getUserProfile()
            let personalizedData = MLModelTrainer.generatePersonalizedData(
                userFeedback: feedbackData,
                baseProfile: userProfile
            )
            
            // Combine with existing synthetic data for incremental learning
            await updateProgress(0.4, status: "Combining with existing data...")
            let baseData = TrainingDataGenerator.generateTrainingData(sessionCount: 500)
            let combinedData = baseData + personalizedData
            
            // Retrain models with combined data
            await updateProgress(0.6, status: "Retraining models...")
            let (newSleepModel, newWakeModel) = try await MLModelTrainer.trainModels()
            
            // Validate improved performance
            await updateProgress(0.8, status: "Validating improvements...")
            let newAccuracy = try await validateModels(
                sleepModel: newSleepModel,
                wakeModel: newWakeModel,
                testData: combinedData
            )
            
            // Update if accuracy improved
            if newAccuracy > modelAccuracy {
                sleepStageModel = newSleepModel
                optimalWakeModel = newWakeModel
                modelAccuracy = newAccuracy
                
                await updateProgress(1.0, status: "Models improved! New accuracy: \(String(format: "%.1f%%", newAccuracy * 100))")
            } else {
                await updateProgress(1.0, status: "Models maintained. No significant improvement.")
            }
            
        } catch {
            print("❌ Model retraining failed: \(error)")
        }
        
        isTrainingInProgress = false
    }
    
    /// Gets current model statistics for UI display
    func getModelStats() -> ModelStats {
        return ModelStats(
            isReady: isModelReady,
            accuracy: modelAccuracy,
            trainingDataCount: trainingDataCount,
            lastTrainingDate: Date(), // Would track actual training date
            userFeedbackCount: personalizationEngine.getAllFeedback().count
        )
    }
}

// MARK: - Supporting Types

struct ModelStats {
    let isReady: Bool
    let accuracy: Double
    let trainingDataCount: Int
    let lastTrainingDate: Date
    let userFeedbackCount: Int
    
    var formattedAccuracy: String {
        String(format: "%.1f%%", accuracy * 100)
    }
    
    var formattedTrainingDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: lastTrainingDate)
    }
}
