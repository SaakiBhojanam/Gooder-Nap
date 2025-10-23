import SwiftUI
import Combine
import NapSyncShared

struct NapMonitoringView: View {
    @StateObject private var viewModel = NapMonitoringViewModel()
    @State private var showingStopConfirmation = false
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 10) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
                
                Text("Monitoring Your Nap")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            .padding(.top, 20)
            
            Spacer()
            
            // Timer Display
            NapTimerView(
                timeElapsed: viewModel.timeElapsed,
                timeRemaining: viewModel.timeRemaining,
                totalDuration: viewModel.totalDuration
            )
            
            // Sleep Stage Indicator
            if let currentStage = viewModel.currentSleepStage {
                VStack(spacing: 8) {
                    Text("Current Sleep Stage")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(currentStage.description)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(colorForSleepStage(currentStage))
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // Wake Window Indicator
            WakeWindowView(
                isInWakeWindow: viewModel.isInWakeWindow,
                nextOptimalWakeTime: viewModel.nextOptimalWakeTime
            )
            
            Spacer()
            
            // Stop Button
            Button(action: {
                showingStopConfirmation = true
            }) {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Stop Nap")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(25)
            }
            .padding(.horizontal, 40)
            
            Text("Your Apple Watch is monitoring your sleep patterns")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)
        }
        .padding()
        .onAppear {
            viewModel.startMonitoring()
        }
        .onDisappear {
            viewModel.stopMonitoring()
        }
        .alert("Stop Nap?", isPresented: $showingStopConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Stop", role: .destructive) {
                Task {
                    await viewModel.stopNap()
                }
            }
        } message: {
            Text("Are you sure you want to end your nap session?")
        }
    }
    
    private func colorForSleepStage(_ stage: SleepStage) -> Color {
        switch stage {
        case .awake:
            return .orange
        case .lightSleep:
            return .green
        case .deepSleep:
            return .blue
        case .rem:
            return .purple
        case .unknown:
            return .gray
        }
    }
}

struct NapTimerView: View {
    let timeElapsed: TimeInterval
    let timeRemaining: TimeInterval
    let totalDuration: TimeInterval
    
    var body: some View {
        VStack(spacing: 20) {
            // Progress Ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: CGFloat(timeElapsed / totalDuration))
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: timeElapsed)
                
                VStack(spacing: 5) {
                    Text(formatTime(timeRemaining))
                        .font(.system(size: 32, weight: .light, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Time Labels
            HStack {
                VStack {
                    Text(formatTime(timeElapsed))
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("Elapsed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text(formatTime(totalDuration))
                        .font(.title3)
                        .fontWeight(.medium)
                    Text("Target")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 40)
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct WakeWindowView: View {
    let isInWakeWindow: Bool
    let nextOptimalWakeTime: Date?
    
    var body: some View {
        VStack(spacing: 8) {
            if isInWakeWindow {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.green)
                    Text("In Optimal Wake Window")
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                }
                
                Text("Looking for the best time to wake you up")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let nextWakeTime = nextOptimalWakeTime {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                    Text("Next optimal wake: \(formatTime(nextWakeTime))")
                        .fontWeight(.medium)
                }
            } else {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.blue)
                    Text("Analyzing sleep patterns")
                        .fontWeight(.medium)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NapMonitoringView()
}