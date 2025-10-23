import SwiftUI
import Combine
import NapSyncShared

@MainActor
class NapMonitoringViewModel: ObservableObject {
    @Published var timeElapsed: TimeInterval = 0
    @Published var timeRemaining: TimeInterval = 0
    @Published var totalDuration: TimeInterval = 0
    @Published var currentSleepStage: SleepStage?
    @Published var isInWakeWindow: Bool = false
    @Published var nextOptimalWakeTime: Date?
    @Published var biometricData: [BiometricDataPoint] = []
    @Published var sleepStages: [SleepStageRecord] = []
    
    private var napSession: NapSession?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private let sleepStageEstimator = SleepStageEstimator()
    private let optimalWakeCalculator = OptimalWakeCalculator()
    private let biometricProcessor = BiometricProcessor()
    private let watchConnectivityManager = WatchConnectivityManager()
    private let alarmService = AlarmService()
    
    init() {
        setupBindings()
    }
    
    private func setupBindings() {
        // Listen for biometric data from watch
        NotificationCenter.default.publisher(for: .biometricDataReceived)
            .compactMap { $0.object as? [String: Any] }
            .sink { [weak self] data in
                self?.processBiometricData(data)
            }
            .store(in: &cancellables)
        
        // Listen for sleep stage updates
        NotificationCenter.default.publisher(for: .sleepStageUpdated)
            .compactMap { $0.object as? [String: Any] }
            .sink { [weak self] data in
                self?.processSleepStageUpdate(data)
            }
            .store(in: &cancellables)
    }
    
    func startMonitoring() {
        // Get current nap session (in a real app, this would come from a shared state)
        // For now, we'll create a sample session
        napSession = createSampleSession()
        
        guard let session = napSession else { return }
        
        totalDuration = session.targetDuration
        updateTimers()
        
        // Start timer for UI updates
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimers()
            self?.checkForOptimalWakeTime()
        }
    }
    
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    func stopNap() async {
        do {
            try await watchConnectivityManager.sendStopNapCommand()
            stopMonitoring()
            
            // End the session and trigger navigation
            NotificationCenter.default.post(name: .napSessionEnded, object: nil)
        } catch {
            print("Failed to stop nap: \(error)")
        }
    }
    
    private func updateTimers() {
        guard let session = napSession else { return }
        
        let now = Date()
        timeElapsed = now.timeIntervalSince(session.startTime)
        timeRemaining = max(0, session.targetEndTime.timeIntervalSince(now))
        
        // Check if we're in the wake window
        let wakeWindowStart = session.targetEndTime.addingTimeInterval(-10 * 60) // 10 minutes before
        isInWakeWindow = now >= wakeWindowStart && now <= session.targetEndTime
    }
    
    private func checkForOptimalWakeTime() {
        guard let session = napSession else { return }
        
        let optimalTimes = optimalWakeCalculator.calculateOptimalWakeTimes(
            sleepStages: sleepStages,
            napStartTime: session.startTime,
            targetEndTime: session.targetEndTime
        )
        
        let (shouldWake, wakeTime) = optimalWakeCalculator.shouldWakeUser(
            optimalTimes: optimalTimes,
            targetEndTime: session.targetEndTime
        )
        
        if shouldWake, let wakeTime = wakeTime {
            Task {
                await triggerWakeAlarm(at: wakeTime)
            }
        } else {
            nextOptimalWakeTime = optimalTimes.first?.timestamp
        }
    }
    
    private func processBiometricData(_ data: [String: Any]) {
        // Parse biometric data from watch
        guard let timestamp = data["timestamp"] as? TimeInterval,
              let heartRate = data["heartRate"] as? Double else { return }
        
        let dataPoint = BiometricDataPoint(
            timestamp: Date(timeIntervalSince1970: timestamp),
            heartRate: heartRate,
            heartRateVariability: data["hrv"] as? Double,
            motionMagnitude: data["motion"] as? Double
        )
        
        biometricData.append(dataPoint)
        
        // Process data in windows for sleep stage estimation
        let windows = biometricProcessor.createWindows(from: biometricData)
        if let latestWindow = windows.last {
            let sleepStage = sleepStageEstimator.estimateSleepStage(from: latestWindow)
            sleepStages.append(sleepStage)
            currentSleepStage = sleepStage.stage
        }
    }
    
    private func processSleepStageUpdate(_ data: [String: Any]) {
        guard let stageString = data["stage"] as? String,
              let stage = SleepStage(rawValue: stageString) else { return }
        
        currentSleepStage = stage
    }
    
    private func triggerWakeAlarm(at wakeTime: OptimalWakeTime) async {
        do {
            await alarmService.triggerAlarm(for: wakeTime)
            stopMonitoring()
            NotificationCenter.default.post(name: .napSessionEnded, object: nil)
        } catch {
            print("Failed to trigger alarm: \(error)")
        }
    }
    
    private func createSampleSession() -> NapSession {
        return NapSession(
            startTime: Date().addingTimeInterval(-300), // Started 5 minutes ago
            targetDuration: 90 * 60, // 90 minutes
            configuration: .default
        )
    }
}