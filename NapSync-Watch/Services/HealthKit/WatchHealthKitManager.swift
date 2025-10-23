import Foundation
import HealthKit
import Combine

@MainActor
class WatchHealthKitManager: ObservableObject {
    @Published var isAuthorized: Bool = false
    
    private let healthStore = HKHealthStore()
    
    private let typesToRead: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .heartRate)!,
        HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    ]
    
    init() {
        checkAuthorizationStatus()
    }
    
    func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        healthStore.requestAuthorization(toShare: [], read: typesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.checkAuthorizationStatus()
            }
        }
    }
    
    private func checkAuthorizationStatus() {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        isAuthorized = healthStore.authorizationStatus(for: heartRateType) == .sharingAuthorized
    }
}