import SwiftUI
import Combine
import WatchKit
import NapSyncShared

@MainActor
class WatchNapViewModel: ObservableObject {
    @Published var currentState: WatchAppState = .ready
    @Published var napSession: NapSession?
    @Published var timeElapsed: TimeInterval = 0
    @Published var currentHeartRate: Double = 0
    @Published var currentSleepStage: SleepStage = .unknown
    @Published var isMonitoring: Bool = false
    
    private var healthKitManager: WatchHealthKitManager?
    private var connectivityService: WatchConnectivityService?
    private var biometricMonitor: BiometricMonitor?
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    func initialize(
        healthKit: WatchHealthKitManager,
        connectivity: WatchConnectivityService,
        monitor: BiometricMonitor
    ) {
        self.healthKitManager = healthKit
        self.connectivityService = connectivity
        self.biometricMonitor = monitor
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Listen for start nap commands from iPhone
        connectivityService?.$receivedStartCommand
            .compactMap { $0 }
            .sink { [weak self] session in
                self?.startNapMonitoring(session: session)
            }
            .store(in: &cancellables)
        
        // Listen for stop commands
        connectivityService?.$receivedStopCommand
            .sink { [weak self] shouldStop in
                if shouldStop {
                    self?.stopNapMonitoring()
                }
            }
            .store(in: &cancellables)
        
        // Monitor biometric data
        biometricMonitor?.$latestBiometricData
            .compactMap { $0 }
            .sink { [weak self] data in
                self?.processBiometricData(data)
            }
            .store(in: &cancellables)
    }
    
    func startNapMonitoring(session: NapSession) {
        napSession = session
        currentState = .monitoring
        isMonitoring = true
        timeElapsed = 0
        currentHeartRate = 0
        currentSleepStage = .unknown

        // Start biometric monitoring
        biometricMonitor?.startMonitoring()

        // Start timer for UI updates
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
        
        // Keep screen awake during monitoring
        WKExtension.shared().isAutorotating = false
    }
    
    func stopNapMonitoring() {
        isMonitoring = false
        timer?.invalidate()
        timer = nil
        
        biometricMonitor?.stopMonitoring()
        
        // Send final data to iPhone
        Task {
            await sendFinalDataToiPhone()
        }

        currentState = .ready
        napSession = nil
        WKExtension.shared().isAutorotating = true
        currentHeartRate = 0
        currentSleepStage = .unknown
        timeElapsed = 0
    }
    
    func triggerAlarm() {
        currentState = .alarm
        
        // Start haptic feedback
        WKInterfaceDevice.current().play(.notification)
        
        // Schedule progressive haptic feedback
        scheduleProgressiveHaptics()
    }
    
    private func updateTimer() {
        guard let session = napSession else { return }
        timeElapsed = Date().timeIntervalSince(session.startTime)
    }
    
    private func processBiometricData(_ data: BiometricDataPoint) {
        if let heartRate = data.heartRate {
            currentHeartRate = heartRate
        }
        
        // Send data to iPhone for processing
        Task {
            await sendBiometricDataToiPhone(data)
        }
    }
    
    private func sendBiometricDataToiPhone(_ data: BiometricDataPoint) async {
        let message: [String: Any] = [
            "command": "biometricData",
            "timestamp": data.timestamp.timeIntervalSince1970,
            "heartRate": data.heartRate ?? 0,
            "hrv": data.heartRateVariability ?? 0,
            "motion": data.motionMagnitude ?? 0
        ]
        
        await connectivityService?.sendMessage(message)
    }
    
    private func sendFinalDataToiPhone() async {
        guard let session = napSession else { return }
        
        let message: [String: Any] = [
            "command": "napComplete",
            "sessionId": session.id.uuidString,
            "actualDuration": timeElapsed
        ]
        
        await connectivityService?.sendMessage(message)
    }
    
    private func scheduleProgressiveHaptics() {
        // Start with gentle haptics, gradually increase intensity
        var intensity = 0
        
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            intensity += 1

            switch intensity {
            case 1...3:
                WKInterfaceDevice.current().play(.click)
            case 4...6:
                WKInterfaceDevice.current().play(.start)
            default:
                WKInterfaceDevice.current().play(.stop)
                timer.invalidate()
            }
        }
    }

    var formattedElapsedTime: String {
        TimeUtils.formatDuration(timeElapsed)
    }

    var formattedRemainingTime: String {
        guard let session = napSession else { return "--" }
        let remaining = max(session.targetDuration - timeElapsed, 0)
        return TimeUtils.formatDuration(remaining)
    }

    var formattedTargetDuration: String {
        guard let session = napSession else { return "--" }
        return TimeUtils.formatDurationShort(session.targetDuration)
    }

    var sessionProgress: Double {
        guard let session = napSession, session.targetDuration > 0 else { return 0 }
        return min(timeElapsed / session.targetDuration, 1.0)
    }

    var hasActiveSession: Bool {
        napSession != nil
    }
}