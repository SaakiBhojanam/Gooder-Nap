import Foundation
import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var authorizationStatus: HKAuthorizationStatus = .notDetermined
    
    private let healthStore = HKHealthStore()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var workoutSession: HKWorkoutSession?
    
    // MARK: - Required HealthKit Types
    private let typesToRead: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    ]
    
    init() {
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit not available on this device")
            return
        }
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                if success {
                    self?.checkAuthorizationStatus()
                } else if let error = error {
                    print("HealthKit authorization failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        authorizationStatus = healthStore.authorizationStatus(for: heartRateType)
        isAuthorized = authorizationStatus == .sharingAuthorized
    }
    
    // MARK: - Data Collection
    
    func startHeartRateMonitoring() -> AsyncStream<Double> {
        return AsyncStream { continuation in
            let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
            
            let query = HKAnchoredObjectQuery(
                type: heartRateType,
                predicate: nil,
                anchor: nil,
                limit: HKObjectQueryNoLimit
            ) { query, samples, deletedObjects, anchor, error in
                
                guard let samples = samples as? [HKQuantitySample] else { return }
                
                for sample in samples {
                    let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    continuation.yield(heartRate)
                }
            }
            
            query.updateHandler = { query, samples, deletedObjects, anchor, error in
                guard let samples = samples as? [HKQuantitySample] else { return }
                
                for sample in samples {
                    let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    continuation.yield(heartRate)
                }
            }
            
            healthStore.execute(query)
            self.heartRateQuery = query
            
            continuation.onTermination = { _ in
                self.healthStore.stop(query)
                self.heartRateQuery = nil
            }
        }
    }
    
    func getHeartRateVariability(from startDate: Date, to endDate: Date) async throws -> [HKQuantitySample] {
        let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: hrvType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { query, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            
            healthStore.execute(query)
        }
    }
    
    func stopMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
        
        workoutSession?.end()
        workoutSession = nil
    }
}