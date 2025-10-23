import Foundation
import CoreData
import NapSyncShared

class NapSessionRepository: ObservableObject {
    private let coreDataManager: CoreDataManager
    
    init(coreDataManager: CoreDataManager = CoreDataManager.shared) {
        self.coreDataManager = coreDataManager
    }
    
    func save(_ session: NapSession) async throws {
        try await coreDataManager.performBackgroundTask { context in
            let entity = NSEntityDescription.entity(forEntityName: "NapSessionEntity", in: context)!
            let sessionEntity = NSManagedObject(entity: entity, insertInto: context)
            
            sessionEntity.setValue(session.id.uuidString, forKey: "id")
            sessionEntity.setValue(session.startTime, forKey: "startTime")
            sessionEntity.setValue(session.targetDuration, forKey: "targetDuration")
            sessionEntity.setValue(session.actualEndTime, forKey: "actualEndTime")
            sessionEntity.setValue(session.targetEndTime, forKey: "targetEndTime")
            sessionEntity.setValue(session.optimalWakeTime, forKey: "optimalWakeTime")
            sessionEntity.setValue(session.wasOptimalWakeUsed, forKey: "wasOptimalWakeUsed")
            
            // Encode configuration as JSON
            let configData = try JSONEncoder().encode(session.configuration)
            sessionEntity.setValue(configData, forKey: "configurationData")
            
            try context.save()
        }
    }
    
    func update(_ session: NapSession) async throws {
        try await coreDataManager.performBackgroundTask { context in
            let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "NapSessionEntity")
            request.predicate = NSPredicate(format: "id == %@", session.id.uuidString)
            
            let results = try context.fetch(request)
            guard let sessionEntity = results.first else { return }
            
            sessionEntity.setValue(session.actualEndTime, forKey: "actualEndTime")
            sessionEntity.setValue(session.optimalWakeTime, forKey: "optimalWakeTime")
            sessionEntity.setValue(session.wasOptimalWakeUsed, forKey: "wasOptimalWakeUsed")
            
            try context.save()
        }
    }
    
    func fetchRecentSessions(limit: Int = 10) async throws -> [NapSession] {
        return try await coreDataManager.performBackgroundTask { context in
            let request: NSFetchRequest<NSManagedObject> = NSFetchRequest(entityName: "NapSessionEntity")
            request.sortDescriptors = [NSSortDescriptor(key: "startTime", ascending: false)]
            request.fetchLimit = limit
            
            let results = try context.fetch(request)
            return results.compactMap { entity in
                self.mapEntityToSession(entity)
            }
        }
    }
    
    private func mapEntityToSession(_ entity: NSManagedObject) -> NapSession? {
        guard let idString = entity.value(forKey: "id") as? String,
              let id = UUID(uuidString: idString),
              let startTime = entity.value(forKey: "startTime") as? Date,
              let targetDuration = entity.value(forKey: "targetDuration") as? TimeInterval,
              let targetEndTime = entity.value(forKey: "targetEndTime") as? Date,
              let configData = entity.value(forKey: "configurationData") as? Data else {
            return nil
        }
        
        let actualEndTime = entity.value(forKey: "actualEndTime") as? Date
        let optimalWakeTime = entity.value(forKey: "optimalWakeTime") as? Date
        let wasOptimalWakeUsed = entity.value(forKey: "wasOptimalWakeUsed") as? Bool ?? false
        
        guard let configuration = try? JSONDecoder().decode(NapConfiguration.self, from: configData) else {
            return nil
        }
        
        // Note: This is a simplified mapping - in a real implementation,
        // you'd also need to fetch related sleep stages and biometric data
        var session = NapSession(
            id: id,
            startTime: startTime,
            targetDuration: targetDuration,
            configuration: configuration
        )
        
        // Update the session with stored values using reflection or a more sophisticated approach
        // For now, we'll create a new session with the basic data
        return session
    }
}

class CoreDataManager: ObservableObject {
    static let shared = CoreDataManager()
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "NapSync")
        container.loadPersistentStores { _, error in
            if let error = error {
                fatalError("Core Data failed to load: \(error.localizedDescription)")
            }
        }
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func save() {
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Failed to save Core Data context: \(error)")
            }
        }
    }
    
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}