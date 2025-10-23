import SwiftUI
import NapSyncShared

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var showingConfiguration = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("NapSync")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Smart nap optimization with your Apple Watch")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 40)
            
            Spacer()
            
            // Duration Picker
            DurationPickerView(
                selectedDuration: $viewModel.selectedDuration,
                onDurationChanged: { duration in
                    viewModel.updateDuration(duration)
                }
            )
            
            Spacer()
            
            // Connection Status
            ConnectionStatusView(
                isWatchConnected: viewModel.isWatchConnected,
                isHealthKitAuthorized: viewModel.healthKitAuthorized
            )
            
            // Error Message
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Start Button
            Button(action: {
                Task {
                    await viewModel.startNap()
                }
            }) {
                HStack {
                    if viewModel.isStartingNap {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "play.fill")
                    }
                    
                    Text(viewModel.isStartingNap ? "Starting..." : "Start Nap")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(viewModel.canStartNap ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(28)
            }
            .disabled(!viewModel.canStartNap)
            .padding(.horizontal, 40)
            
            // Settings Button
            Button("Nap Settings") {
                showingConfiguration = true
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingConfiguration) {
            NapConfigurationView(configuration: $viewModel.napConfiguration)
        }
    }
}

struct DurationPickerView: View {
    @Binding var selectedDuration: TimeInterval
    let onDurationChanged: (TimeInterval) -> Void
    
    private let durations: [TimeInterval] = [
        20 * 60,  // 20 minutes
        30 * 60,  // 30 minutes
        45 * 60,  // 45 minutes
        60 * 60,  // 1 hour
        90 * 60,  // 1.5 hours
        120 * 60  // 2 hours
    ]
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Nap Duration")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(formattedDuration)
                .font(.system(size: 48, weight: .light, design: .rounded))
                .foregroundColor(.blue)
            
            Picker("Duration", selection: $selectedDuration) {
                ForEach(durations, id: \.self) { duration in
                    Text(formatDuration(duration))
                        .tag(duration)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .onChange(of: selectedDuration) { newValue in
                onDurationChanged(newValue)
            }
        }
    }
    
    private var formattedDuration: String {
        formatDuration(selectedDuration)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct ConnectionStatusView: View {
    let isWatchConnected: Bool
    let isHealthKitAuthorized: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 15) {
                StatusIndicator(
                    isConnected: isWatchConnected,
                    icon: "applewatch",
                    label: "Apple Watch"
                )
                
                StatusIndicator(
                    isConnected: isHealthKitAuthorized,
                    icon: "heart.fill",
                    label: "HealthKit"
                )
            }
            
            if !isWatchConnected || !isHealthKitAuthorized {
                Text("Please ensure your Apple Watch is connected and HealthKit access is granted")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StatusIndicator: View {
    let isConnected: Bool
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isConnected ? .green : .red)
            
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
            
            Circle()
                .fill(isConnected ? Color.green : Color.red)
                .frame(width: 8, height: 8)
        }
    }
}

struct NapConfigurationView: View {
    @Binding var configuration: NapConfiguration
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Alarm") {
                    Picker("Alarm Tone", selection: $configuration.alarmTone) {
                        ForEach(AlarmTone.allCases, id: \.self) { tone in
                            Text(tone.displayName).tag(tone)
                        }
                    }
                    
                    Picker("Haptic Intensity", selection: $configuration.hapticIntensity) {
                        ForEach(HapticIntensity.allCases, id: \.self) { intensity in
                            Text(intensity.displayName).tag(intensity)
                        }
                    }
                }
                
                Section("Wake Window") {
                    Stepper("Look for optimal wake time \(configuration.wakeWindowMinutes) minutes before target",
                            value: $configuration.wakeWindowMinutes,
                            in: 5...30,
                            step: 5)
                }
                
                Section("Features") {
                    Toggle("Gentle Wake", isOn: $configuration.enableGentleWake)
                    Toggle("Progressive Alarm", isOn: $configuration.enableProgressiveAlarm)
                }
            }
            .navigationTitle("Nap Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    HomeView(viewModel: HomeViewModel())
}