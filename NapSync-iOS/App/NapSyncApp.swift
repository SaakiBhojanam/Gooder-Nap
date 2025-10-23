import SwiftUI
import NapSyncShared

@main
struct NapSyncApp: App {
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var watchConnectivityManager = WatchConnectivityManager()
    @StateObject private var coreDataManager = CoreDataManager()
    @StateObject private var mlModelService = MLModelService.shared
    
    var body: some Scene {
        WindowGroup {
            if mlModelService.isModelReady {
                ContentView()
                    .environmentObject(healthKitManager)
                    .environmentObject(watchConnectivityManager)
                    .environmentObject(coreDataManager)
                    .environmentObject(mlModelService)
            } else {
                MLTrainingView()
                    .environmentObject(mlModelService)
            }
        }
        .onChange(of: mlModelService.isModelReady) { isReady in
            if isReady {
                setupApp()
            }
        }
    }
    
    private func setupApp() {
        // Initialize core services after ML models are ready
        healthKitManager.requestAuthorization()
        watchConnectivityManager.startSession()
    }
}
