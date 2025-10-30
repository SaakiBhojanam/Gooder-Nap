import SwiftUI
import WatchKit
import NapSyncShared

@main
struct NapSyncWatchApp: App {
    @StateObject private var watchHealthKitManager = WatchHealthKitManager()
    @StateObject private var watchConnectivityService = WatchConnectivityService()
    @StateObject private var biometricMonitor = BiometricMonitor()
    
var body: some Scene {
    WindowGroup {
        NavigationStack {
            ContentView()
                .environmentObject(watchHealthKitManager)
                .environmentObject(watchConnectivityService)
                .environmentObject(biometricMonitor)
        }
    }
}
}

struct ContentView: View {
    @EnvironmentObject var watchHealthKitManager: WatchHealthKitManager
    @EnvironmentObject var watchConnectivityService: WatchConnectivityService
    @EnvironmentObject var biometricMonitor: BiometricMonitor
    @StateObject private var viewModel = WatchNapViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch viewModel.currentState {
            case .ready:
                ReadyToNapView()
            case .monitoring:
                MonitoringView()
            case .alarm:
                AlarmView()
            }
        }
        .environmentObject(viewModel)
        .onAppear {
            initializeDependenciesIfNeeded()
            handleActivationEvents()
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .active {
                handleActivationEvents()
            }
        }
        .onChange(of: watchConnectivityService.isReachable) { isReachable in
            if isReachable {
                watchConnectivityService.notifyCompanionReady()
            }
        }
    }

    private func initializeDependenciesIfNeeded() {
        viewModel.initialize(
            healthKit: watchHealthKitManager,
            connectivity: watchConnectivityService,
            monitor: biometricMonitor
        )
    }

    private func handleActivationEvents() {
        if !watchHealthKitManager.isAuthorized {
            watchHealthKitManager.requestAuthorization()
        }

        watchConnectivityService.notifyCompanionReady()
    }
}

enum WatchAppState {
    case ready
    case monitoring
    case alarm
}