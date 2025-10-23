import Foundation
import NapSyncShared

/// ML-generated insights about nap quality and patterns
struct MLInsights {
    let predictedOptimalDuration: TimeInterval
    let sleepEfficiency: Double
    let dominantSleepStage: SleepStage
    let personalizedScore: Double
    let improvementSuggestions: [String]
    
    var formattedOptimalDuration: String {
        TimeUtils.formatDurationShort(predictedOptimalDuration)
    }
    
    var formattedEfficiency: String {
        String(format: "%.1f%%", sleepEfficiency * 100)
    }
    
    var formattedScore: String {
        String(format: "%.1f/10", personalizedScore * 10)
    }
    
    var efficiencyColor: Color {
        switch sleepEfficiency {
        case 0.8...: return .green
        case 0.6..<0.8: return .orange
        default: return .red
        }
    }
}

/// Extended repository for handling ML feedback
extension NapSessionRepository {
    func saveFeedback(_ feedback: NapFeedback) async throws {
        // In a real implementation, this would save feedback to CoreData
        // and potentially sync with cloud services for ML training
        print("💾 Saving feedback: Quality \(feedback.qualityRating)/5")
        
        try await coreDataManager.performBackgroundTask { context in
            let entity = NSEntityDescription.entity(forEntityName: "FeedbackEntity", in: context)!
            let feedbackEntity = NSManagedObject(entity: entity, insertInto: context)
            
            feedbackEntity.setValue(feedback.napSession.id.uuidString, forKey: "sessionId")
            feedbackEntity.setValue(feedback.qualityRating, forKey: "qualityRating")
            feedbackEntity.setValue(feedback.postNapFeeling.rawValue, forKey: "postNapFeeling")
            feedbackEntity.setValue(feedback.wasWakeTimeOptimal, forKey: "wasWakeTimeOptimal")
            feedbackEntity.setValue(feedback.timestamp, forKey: "timestamp")
            
            // Encode biometric data as JSON
            let biometricData = try JSONEncoder().encode(feedback.sessionBiometrics)
            feedbackEntity.setValue(biometricData, forKey: "biometricData")
            
            try context.save()
        }
    }
    
    func loadRecentFeedback(limit: Int = 50) async throws -> [NapFeedback] {
        return try await coreDataManager.performBackgroundTask { context in
            let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "FeedbackEntity")
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            request.fetchLimit = limit
            
            let results = try context.fetch(request)
            return results.compactMap { entity in
                // Map entity back to NapFeedback
                // This would be implemented with proper CoreData mapping
                return nil // Placeholder for demo
            }
        }
    }
}

import SwiftUI

extension Color {
    static let mlBlue = Color(red: 0.2, green: 0.6, blue: 1.0)
    static let mlGreen = Color(red: 0.2, green: 0.8, blue: 0.4)
    static let mlOrange = Color(red: 1.0, green: 0.6, blue: 0.2)
}