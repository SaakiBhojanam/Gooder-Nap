//
//  ContentView.swift
//  NapSync
//
//  Created by AI Club on 10/22/25.
//

import SwiftUI

// Mock environment objects for standalone testing
class MockHealthKitManager: ObservableObject {
    @Published var isAuthorized = false
}

class MockWatchConnectivityManager: ObservableObject {
    @Published var isConnected = false
}

class MockHomeViewModel: ObservableObject {
    @Published var napDuration: TimeInterval = 1800 // 30 minutes
    @Published var isNapping = false
}

enum AppView {
    case home
    case history
    case insights
    case settings
}

struct ContentView: View {
    @StateObject private var healthKitManager = MockHealthKitManager()
    @StateObject private var watchConnectivityManager = MockWatchConnectivityManager()
    @StateObject private var homeViewModel = MockHomeViewModel()
    @StateObject private var mlModelService = MLModelService.shared
    @State private var currentView: AppView = .home
    @State private var showMLTraining = true
    
    var body: some View {
        NavigationStack {
            if showMLTraining && !mlModelService.isModelTrained {
                // Show ML Training View on first launch
                MLTrainingView()
                    .environmentObject(mlModelService)
                    .onReceive(mlModelService.$isModelTrained) { isTrained in
                        if isTrained {
                            showMLTraining = false
                        }
                    }
            } else {
                // Main app interface
                TabView(selection: $currentView) {
                    HomeTab()
                        .tabItem {
                            Image(systemName: "house.fill")
                            Text("Home")
                        }
                        .tag(AppView.home)
                    
                    HistoryTab()
                        .tabItem {
                            Image(systemName: "clock.fill")
                            Text("History")
                        }
                        .tag(AppView.history)
                    
                    InsightsTab()
                        .tabItem {
                            Image(systemName: "brain.head.profile")
                            Text("Insights")
                        }
                        .tag(AppView.insights)
                    
                    SettingsTab()
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                        .tag(AppView.settings)
                }
                .environmentObject(healthKitManager)
                .environmentObject(watchConnectivityManager)
                .environmentObject(homeViewModel)
                .environmentObject(mlModelService)
            }
        }
        .onAppear {
            // Initialize ML models on app launch
            mlModelService.initializeMLModels()
        }
    }
}

// MARK: - Tab Views

struct HomeTab: View {
    @EnvironmentObject var homeViewModel: MockHomeViewModel
    @EnvironmentObject var mlModelService: MLModelService
    
    var body: some View {
        VStack(spacing: 20) {
            Text("NapSync")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("AI-Powered Nap Optimization")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            VStack(spacing: 16) {
                HStack {
                    Text("Nap Duration:")
                    Spacer()
                    Text("\(Int(homeViewModel.napDuration / 60)) min")
                        .fontWeight(.medium)
                }
                
                Slider(value: $homeViewModel.napDuration, in: 600...5400, step: 300) // 10min - 90min
                    .accentColor(.blue)
            }
            .padding()
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
            
            Button(action: {
                homeViewModel.isNapping.toggle()
            }) {
                Text(homeViewModel.isNapping ? "Stop Nap" : "Start Nap")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(homeViewModel.isNapping ? Color.red : Color.blue)
                    .cornerRadius(16)
            }
            
            if homeViewModel.isNapping {
                Text("Monitoring your nap...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Home")
    }
}

struct HistoryTab: View {
    var body: some View {
        VStack {
            Text("Nap History")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your previous nap sessions will appear here")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()
            
            Spacer()
        }
        .padding()
        .navigationTitle("History")
    }
}

struct InsightsTab: View {
    @EnvironmentObject var mlModelService: MLModelService
    
    var body: some View {
        VStack(spacing: 20) {
            Text("ML Insights")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                InsightCard(
                    title: "Model Status",
                    value: mlModelService.isModelTrained ? "Trained" : "Training...",
                    color: mlModelService.isModelTrained ? .green : .orange
                )
                
                InsightCard(
                    title: "Training Data",
                    value: "\(mlModelService.trainingDataCount) sessions",
                    color: .blue
                )
                
                InsightCard(
                    title: "Model Accuracy",
                    value: String(format: "%.1f%%", mlModelService.modelAccuracy * 100),
                    color: .purple
                )
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Insights")
    }
}

struct InsightCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            Spacer()
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

struct SettingsTab: View {
    @EnvironmentObject var healthKitManager: MockHealthKitManager
    @EnvironmentObject var watchConnectivityManager: MockWatchConnectivityManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            VStack(spacing: 16) {
                SettingRow(
                    title: "HealthKit",
                    status: healthKitManager.isAuthorized ? "Authorized" : "Not Authorized",
                    statusColor: healthKitManager.isAuthorized ? .green : .red
                )
                
                SettingRow(
                    title: "Apple Watch",
                    status: watchConnectivityManager.isConnected ? "Connected" : "Not Connected",
                    statusColor: watchConnectivityManager.isConnected ? .green : .red
                )
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Settings")
    }
}

struct SettingRow: View {
    let title: String
    let status: String
    let statusColor: Color

    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Text(status)
                .font(.subheadline)
                .foregroundColor(statusColor)
        }
        .padding()
        .background(Color.gray.opacity(0.15))
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
}
