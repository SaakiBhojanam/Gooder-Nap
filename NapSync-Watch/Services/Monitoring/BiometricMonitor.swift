import Foundation
import HealthKit
import CoreMotion
import Combine
import NapSyncShared

@MainActor
class BiometricMonitor: ObservableObject {
    @Published var latestBiometricData: BiometricDataPoint?
    @Published var isMonitoring: Bool = false
    
    private let healthStore = HKHealthStore()
    private let motionManager = CMMotionManager()
    private var heartRateQuery: HKAnchoredObjectQuery?
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    private let sleepStageEstimator = SleepStageEstimator()
    private let biometricProcessor = BiometricProcessor()
    
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        
        // Start workout session for background execution
        startWorkoutSession()
        
        // Start heart rate monitoring
        startHeartRateMonitoring()
        
        // Start motion monitoring
        startMotionMonitoring()
    }
    
    func stopMonitoring() {
        isMonitoring = false
        
        // Stop all monitoring
        stopHeartRateMonitoring()
        stopMotionMonitoring()
        endWorkoutSession()
    }
    
    private func startWorkoutSession() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .other
        configuration.locationType = .indoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            workoutSession?.startActivity(with: Date())
            workoutBuilder?.beginCollection(withStart: Date()) { success, error in
                if let error = error {
                    print("Failed to start workout: \(error)")
                }
            }
        } catch {
            print("Failed to create workout session: \(error)")
        }
    }
    
    private func endWorkoutSession() {
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date()) { success, error in
            if success {
                self.workoutBuilder?.finishWorkout { workout, error in
                    // Workout finished
                }
            }
        }
    }
    
    private func startHeartRateMonitoring() {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        
        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples as? [HKQuantitySample] ?? [])
        }
        
        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples as? [HKQuantitySample] ?? [])
        }
        
        healthStore.execute(query)
        heartRateQuery = query
    }
    
    private func stopHeartRateMonitoring() {
        if let query = heartRateQuery {
            healthStore.stop(query)
            heartRateQuery = nil
        }
    }
    
    private func startMotionMonitoring() {
        guard motionManager.isAccelerometerAvailable else { return }
        
        motionManager.accelerometerUpdateInterval = 1.0 // 1 second intervals
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            if let accelerometerData = data {
                self?.processMotionData(accelerometerData)
            }
        }
    }
    
    private func stopMotionMonitoring() {
        motionManager.stopAccelerometerUpdates()
    }
    
    private func processHeartRateSamples(_ samples: [HKQuantitySample]) {
        guard let latestSample = samples.last else { return }
        
        let heartRate = latestSample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
        
        // Create or update current biometric data point
        updateBiometricData(heartRate: heartRate, timestamp: latestSample.startDate)
    }
    
    private func processMotionData(_ data: CMAccelerometerData) {
        let magnitude = sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))
        
        updateBiometricData(motionMagnitude: magnitude, timestamp: Date())
    }
    
    private func updateBiometricData(
        heartRate: Double? = nil,
        motionMagnitude: Double? = nil,
        timestamp: Date
    ) {
        let dataPoint = BiometricDataPoint(
            timestamp: timestamp,
            heartRate: heartRate,
            heartRateVariability: nil, // Would need additional processing for HRV
            motionMagnitude: motionMagnitude
        )
        
        latestBiometricData = dataPoint
    }
}