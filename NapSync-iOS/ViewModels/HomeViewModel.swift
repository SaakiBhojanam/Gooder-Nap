import SwiftUI
import Combine
import NapSyncShared

@MainActor
class HomeViewModel: ObservableObject {
    @Published var selectedDuration: TimeInterval = 90 * 60 // 90 minutes default
    @Published var napSession: NapSession?
    @Published var isWatchConnected: Bool = false
    @Published var healthKitAuthorized: Bool = false
    @Published var isStartingNap: Bool = false
    @Published var errorMessage: String?
    @Published var napConfiguration: NapConfiguration = .default
    
    private let healthKitManager: HealthKitManager
    private let watchConnectivityManager: WatchConnectivityManager
    private let napSessionRepository: NapSessionRepository
    private var cancellables = Set<AnyCancellable>()
    
    init(
        healthKitManager: HealthKitManager = HealthKitManager(),
        watchConnectivityManager: WatchConnectivityManager = WatchConnectivityManager(),
        napSessionRepository: NapSessionRepository = NapSessionRepository()
    ) {
        self.healthKitManager = healthKitManager
        self.watchConnectivityManager = watchConnectivityManager
        self.napSessionRepository = napSessionRepository
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Monitor watch connectivity
        watchConnectivityManager.$isConnected
            .receive(on: DispatchQueue.main)
            .assign(to: &$isWatchConnected)
        
        // Monitor HealthKit authorization
        healthKitManager.$isAuthorized
            .receive(on: DispatchQueue.main)
            .assign(to: &$healthKitAuthorized)
    }
    
    // MARK: - Public Methods
    
    func startNap() async {
        guard healthKitAuthorized else {
            errorMessage = "HealthKit access is required to monitor your nap"
            return
        }
        
        guard isWatchConnected else {
            errorMessage = "Apple Watch must be connected to start a nap session"
            return
        }
        
        isStartingNap = true
        errorMessage = nil
        
        do {
            // Create new nap session
            let session = NapSession(
                startTime: Date(),
                targetDuration: selectedDuration,
                configuration: napConfiguration
            )
            
            // Save session to repository
            try await napSessionRepository.save(session)
            
            // Send start command to watch
            try await watchConnectivityManager.sendStartNapCommand(session: session)
            
            // Update published session
            napSession = session
            
        } catch {
            errorMessage = "Failed to start nap session: \(error.localizedDescription)"
        }
        
        isStartingNap = false
    }
    
    func updateDuration(_ duration: TimeInterval) {
        selectedDuration = duration
    }
    
    func updateConfiguration(_ config: NapConfiguration) {
        napConfiguration = config
    }
    
    var canStartNap: Bool {
        return healthKitAuthorized && isWatchConnected && !isStartingNap
    }
    
    var formattedDuration: String {
        let hours = Int(selectedDuration) / 3600
        let minutes = (Int(selectedDuration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}