import SwiftUI
import NapSyncShared

struct ReadyToNapView: View {
    @EnvironmentObject var viewModel: WatchNapViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "moon.zzz.fill")
                .font(.largeTitle)
                .foregroundColor(.blue)
            
            Text("NapSync")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Ready for nap")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let session = viewModel.napSession {
                VStack(spacing: 8) {
                    Text("Duration")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(TimeUtils.formatDurationShort(session.targetDuration))
                        .font(.title2)
                        .fontWeight(.medium)
                }
            }
            
            Text("Waiting for iPhone...")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding()
    }
}

struct MonitoringView: View {
    @EnvironmentObject var viewModel: WatchNapViewModel
    
    var body: some View {
        VStack(spacing: 15) {
            // Status indicator
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                
                Text("Monitoring")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            // Time elapsed
            VStack(spacing: 5) {
                Text(TimeUtils.formatDuration(viewModel.timeElapsed))
                    .font(.title)
                    .fontWeight(.light)
                
                Text("elapsed")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Heart rate
            if viewModel.currentHeartRate > 0 {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                    
                    Text("\(Int(viewModel.currentHeartRate)) BPM")
                        .font(.caption)
                }
            }
            
            // Sleep stage
            if viewModel.currentSleepStage != .unknown {
                Text(viewModel.currentSleepStage.description)
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            
            Spacer()
            
            // Minimal interaction - just emergency stop
            Button("Stop") {
                viewModel.stopNapMonitoring()
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding()
        .digitalCrownRotation($viewModel.timeElapsed) // Allow crown scrolling to see time
    }
}

struct AlarmView: View {
    @EnvironmentObject var viewModel: WatchNapViewModel
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        VStack(spacing: 20) {
            // Pulsing wake icon
            Image(systemName: "alarm.fill")
                .font(.largeTitle)
                .foregroundColor(.orange)
                .scaleEffect(pulseScale)
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                        pulseScale = 1.3
                    }
                }
            
            Text("Wake Up!")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.orange)
            
            Text("Tap to dismiss")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .onTapGesture {
            viewModel.stopNapMonitoring()
        }
        .onAppear {
            // Ensure haptic feedback continues
            viewModel.triggerAlarm()
        }
    }
}

#Preview("Ready") {
    ReadyToNapView()
        .environmentObject(WatchNapViewModel())
}

#Preview("Monitoring") {
    MonitoringView()
        .environmentObject(WatchNapViewModel())
}

#Preview("Alarm") {
    AlarmView()
        .environmentObject(WatchNapViewModel())
}