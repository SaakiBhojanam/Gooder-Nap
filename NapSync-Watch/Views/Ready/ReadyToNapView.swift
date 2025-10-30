import SwiftUI
import NapSyncShared

struct ReadyToNapView: View {
    @EnvironmentObject var viewModel: WatchNapViewModel
    @EnvironmentObject var healthKit: WatchHealthKitManager
    @EnvironmentObject var connectivity: WatchConnectivityService

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header

                VStack(spacing: 12) {
                    connectionTile
                    healthTile

                    if !healthKit.isAuthorized {
                        Button("Enable Health Access") {
                            healthKit.requestAuthorization()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }

                sessionSection

                Text("Start a nap from your iPhone to begin monitoring here.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
        .navigationTitle("NapSync")
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 42))
                .foregroundColor(.blue)

            Text("NapSync")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Ready for your next nap")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var connectionTile: some View {
        StatusTile(
            icon: connectivityIcon,
            title: "Companion",
            value: connectivityStatus,
            tint: connectivityTint
        )
    }

    private var healthTile: some View {
        StatusTile(
            icon: healthKit.isAuthorized ? "heart.fill" : "heart.slash",
            title: "Health",
            value: healthKit.isAuthorized ? "Authorized" : "Tap to authorize",
            tint: healthKit.isAuthorized ? .pink : .orange
        )
    }

    private var sessionSection: some View {
        Group {
            if let session = viewModel.napSession {
                VStack(spacing: 12) {
                    StatusTile(
                        icon: "timer",
                        title: "Target Nap",
                        value: TimeUtils.formatDurationShort(session.targetDuration),
                        tint: .purple
                    )

                    HStack(spacing: 8) {
                        MetricChip(title: "Start", value: startTimeText(for: session), tint: .blue)
                        MetricChip(title: "Target", value: TimeUtils.formatDurationShort(session.targetDuration), tint: .teal)
                    }

                    Text("Waiting for optimal start signal from iPhone")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } else {
                StatusTile(
                    icon: "iphone.and.applewatch",
                    title: "Session",
                    value: "Awaiting nap configuration",
                    tint: .blue
                )
            }
        }
    }

    private var connectivityIcon: String {
        if connectivity.isReachable {
            return "dot.radiowaves.left.and.right"
        }
        if connectivity.isConnected {
            return "wave.3.forward"
        }
        return "iphone.slash"
    }

    private var connectivityStatus: String {
        if connectivity.isReachable {
            return "Connected to iPhone"
        }
        if connectivity.isConnected {
            return "Pairing active"
        }
        return "Not connected"
    }

    private var connectivityTint: Color {
        if connectivity.isReachable {
            return .green
        }
        if connectivity.isConnected {
            return .orange
        }
        return .red
    }

    private func startTimeText(for session: NapSession) -> String {
        ReadyToNapView.startFormatter.string(from: session.startTime)
    }
}

extension ReadyToNapView {
    private static let startFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()
}

struct MonitoringView: View {
    @EnvironmentObject var viewModel: WatchNapViewModel
    @EnvironmentObject var connectivity: WatchConnectivityService

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StatusTile(
                    icon: "waveform.path.ecg",
                    title: "Status",
                    value: "Monitoring active",
                    tint: .green
                )

                VStack(spacing: 8) {
                    Text(viewModel.formattedElapsedTime)
                        .font(.system(size: 32, weight: .medium, design: .rounded))
                        .monospacedDigit()

                    if viewModel.hasActiveSession {
                        Text("of \(viewModel.formattedTargetDuration)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        ProgressView(value: viewModel.sessionProgress)
                            .progressViewStyle(.linear)
                            .tint(.green)
                    }
                }

                if viewModel.hasActiveSession {
                    HStack(spacing: 8) {
                        MetricChip(title: "Remaining", value: viewModel.formattedRemainingTime, tint: .blue)
                        MetricChip(title: "Target", value: viewModel.formattedTargetDuration, tint: .purple)
                    }
                }

                if viewModel.currentHeartRate > 0 {
                    StatusTile(
                        icon: "heart.fill",
                        title: "Heart Rate",
                        value: "\(Int(viewModel.currentHeartRate)) BPM",
                        tint: .red
                    )
                }

                StatusTile(
                    icon: "bed.double.fill",
                    title: "Sleep Stage",
                    value: viewModel.currentSleepStage.description,
                    tint: .teal
                )

                StatusTile(
                    icon: connectivity.isReachable ? "dot.radiowaves.left.and.right" : "iphone.slash",
                    title: "Companion",
                    value: connectivity.isReachable ? "Connected" : "Awaiting connection",
                    tint: connectivity.isReachable ? .green : .orange
                )

                Button("Stop Monitoring") {
                    viewModel.stopNapMonitoring()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
        .navigationTitle("Monitoring")
    }
}

struct AlarmView: View {
    @EnvironmentObject var viewModel: WatchNapViewModel
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.orange.opacity(0.9), .red.opacity(0.9)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "alarm.fill")
                    .font(.system(size: 46))
                    .foregroundColor(.white)
                    .scaleEffect(pulseScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            pulseScale = 1.25
                        }
                    }

                Text("Wake Up!")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Tap to dismiss")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))

                Button("Stop Alarm") {
                    viewModel.stopNapMonitoring()
                }
                .buttonStyle(.borderedProminent)
                .tint(.white)
                .foregroundColor(.orange)
            }
            .padding(24)
        }
        .onTapGesture {
            viewModel.stopNapMonitoring()
        }
        .onAppear {
            viewModel.triggerAlarm()
        }
        .navigationTitle("Alarm")
    }
}

#Preview("Ready") {
    let viewModel = WatchNapViewModel()
    viewModel.napSession = NapSession(
        startTime: Date(),
        targetDuration: 60 * 30,
        configuration: .default
    )

    let healthKit = WatchHealthKitManager()
    healthKit.isAuthorized = true

    let connectivity = WatchConnectivityService()
    connectivity.isConnected = true
    connectivity.isReachable = true

    return NavigationStack {
        ReadyToNapView()
            .environmentObject(viewModel)
            .environmentObject(healthKit)
            .environmentObject(connectivity)
    }
}

#Preview("Monitoring") {
    let viewModel = WatchNapViewModel()
    viewModel.napSession = NapSession(
        startTime: Date().addingTimeInterval(-600),
        targetDuration: 60 * 30,
        configuration: .default
    )
    viewModel.timeElapsed = 600
    viewModel.currentHeartRate = 58
    viewModel.currentSleepStage = .lightSleep

    let connectivity = WatchConnectivityService()
    connectivity.isConnected = true
    connectivity.isReachable = true

    return NavigationStack {
        MonitoringView()
            .environmentObject(viewModel)
            .environmentObject(connectivity)
    }
}

#Preview("Alarm") {
    let viewModel = WatchNapViewModel()
    return NavigationStack {
        AlarmView()
            .environmentObject(viewModel)
    }
}
