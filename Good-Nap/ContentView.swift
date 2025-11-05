//
//  ContentView.swift
//  NapSync
//
//  Created by AI Club on 10/22/25.
//

import SwiftUI

// MARK: - Mock environment objects for standalone testing

class MockHealthKitManager: ObservableObject {
    @Published var isAuthorized = false
}

class MockWatchConnectivityManager: ObservableObject {
    @Published var isConnected = false
}

@MainActor
class MockHomeViewModel: ObservableObject {
    @Published var napDuration: TimeInterval = 1800 { // 30 minutes
        didSet {
            guard !isNapping else { return }
            remainingNapTime = napDuration
            refreshSoundscapePlan()
        }
    }
    @Published private(set) var isNapping = false
    @Published var isSoundscapeEnabled = false {
        didSet { refreshSoundscapePlan() }
    }
    @Published var soundscapePlan: SoundscapePlan?
    @Published var remainingNapTime: TimeInterval = 1800
    @Published var biometrics = SleepBiometrics(
        restingHeartRate: 62,
        heartRateVariability: 58,
        respiratoryRate: 12.4,
        microMovementIndex: 0.18
    ) {
        didSet { refreshSoundscapePlan() }
    }

    private let soundscapeService = SoundscapeService.shared
    private var napTimer: Timer?

    private func refreshSoundscapePlan() {
        guard isSoundscapeEnabled else {
            soundscapePlan = nil
            // Stop audio playback when soundscape is disabled
            Task { @MainActor in
                SoundscapeAudioEngine.shared.stopPlayback()
            }
            return
        }

        soundscapePlan = soundscapeService.generatePlan(
            napDuration: napDuration,
            biometrics: biometrics
        )

        if isNapping {
            Task { @MainActor in
                SoundscapeAudioEngine.shared.configurePlayback(
                    for: soundscapePlan!,
                    napDuration: napDuration,
                    remainingNapTime: remainingNapTime,
                    preview: false
                )
            }
        }
    }

    func toggleNapState() {
        if isNapping {
            endNap()
        } else {
            startNap()
        }
    }

    private func startNap() {
        napTimer?.invalidate()
        remainingNapTime = napDuration
        isNapping = true
        refreshSoundscapePlan()

        if isSoundscapeEnabled, let plan = soundscapePlan {
            Task { @MainActor in
                SoundscapeAudioEngine.shared.configurePlayback(
                    for: plan,
                    napDuration: napDuration,
                    remainingNapTime: remainingNapTime,
                    preview: false
                )
            }
        }

        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            DispatchQueue.main.async {
                if self.remainingNapTime > 1 {
                    self.remainingNapTime -= 1
                } else {
                    self.remainingNapTime = 0
                    timer.invalidate()
                    self.napTimer = nil
                    self.endNap()
                }
            }
        }

        RunLoop.main.add(timer, forMode: .common)
        napTimer = timer
    }

    private func endNap() {
        napTimer?.invalidate()
        napTimer = nil
        isNapping = false
        remainingNapTime = napDuration
        refreshSoundscapePlan()

        if isSoundscapeEnabled {
            Task { @MainActor in
                SoundscapeAudioEngine.shared.stopPlayback()
            }
        }
    }
}

// MARK: - App Views

enum AppView: Hashable {
    case home
    case history
    case analytics
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

                    AnalyticsTab()
                        .tabItem {
                            Image(systemName: "waveform.path.ecg")
                            Text("Analytics")
                        }
                        .tag(AppView.analytics)

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
    @EnvironmentObject private var homeViewModel: MockHomeViewModel
    @EnvironmentObject private var mlModelService: MLModelService
    @EnvironmentObject private var watchConnectivityManager: MockWatchConnectivityManager

    private var isPremiumReady: Bool {
        mlModelService.isModelTrained && homeViewModel.isNapping
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(.systemIndigo).opacity(0.25), Color(.systemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    NapCycleTrackerView(
                        napDuration: homeViewModel.napDuration,
                        isNapping: homeViewModel.isNapping,
                        isModelTrained: mlModelService.isModelTrained,
                        remainingTime: homeViewModel.remainingNapTime
                    )

                    WatchPreviewCard(isConnected: watchConnectivityManager.isConnected)

                    controlPanel

                    if homeViewModel.isSoundscapeEnabled, let plan = homeViewModel.soundscapePlan {
                        SoundscapePlanCard(plan: plan)
                    }

                    if homeViewModel.isNapping {
                        statusHighlights
                    }
                }
                .padding(.vertical, 24)
                .padding(.horizontal, 20)
            }
        }
        .navigationTitle("Home")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NapSync")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text("Smart nap cycles powered by adaptive sleep science")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Label("Adaptive AI", systemImage: "sparkles")
                Label(mlModelService.isModelTrained ? "Model Ready" : "Training Model", systemImage: mlModelService.isModelTrained ? "checkmark.seal.fill" : "hourglass")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Nap Window")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(Int(homeViewModel.napDuration / 60)) minutes")
                        .font(.title3.weight(.semibold))
                }
                Spacer()
                Capsule()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 86, height: 32)
                    .overlay(
                        Text(isPremiumReady ? "Live" : "Planning")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                    )
            }

            Slider(value: $homeViewModel.napDuration, in: 600...5400, step: 300)
                .tint(.blue)
                .disabled(homeViewModel.isNapping)

            Toggle(isOn: $homeViewModel.isSoundscapeEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable Soundscape wake-up")
                        .font(.body.weight(.semibold))
                    Text("Progressive alarm that layers gentle tones based on your biometrics.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(CustomCheckboxToggleStyle())

            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    homeViewModel.toggleNapState()
                }
            }) {
                Text(homeViewModel.isNapping ? "End Optimized Nap" : "Begin Optimized Nap")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(colors: homeViewModel.isNapping ? [.red, .pink] : [.blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: (homeViewModel.isNapping ? Color.red.opacity(0.35) : Color.blue.opacity(0.35)), radius: 14, x: 0, y: 10)
            }
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.2))
        )
    }

    private var statusHighlights: some View {
        VStack(spacing: 16) {
            HighlightRow(
                icon: "bolt.heart.fill",
                title: "Adaptive wake-up window",
                detail: "We’ll gently wake you when your body reaches the ideal REM exit point."
            )

            HighlightRow(
                icon: "aqi.medium",
                title: "Real-time rhythm tracking",
                detail: "Heart rate variability, micro-movements, and breathing cadence stay synced to your watch."
            )
        }
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.2))
        )
    }
}

struct HighlightRow: View {
    let icon: String
    let title: String
    let detail: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
    }
}

struct NapCycleTrackerView: View {
    let napDuration: TimeInterval
    let isNapping: Bool
    let isModelTrained: Bool
    let remainingTime: TimeInterval
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Nap Cycle Tracker")
                    .font(.title3.weight(.semibold))
                Spacer()
                Text(isNapping ? "Active" : "Ready")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isNapping ? Color.green : Color.blue, in: Capsule())
                    .foregroundColor(.white)
            }
            
            if isNapping {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Remaining: \(Int(remainingTime / 60))m \(Int(remainingTime.truncatingRemainder(dividingBy: 60)))s")
                        .font(.headline)
                    
                    ProgressView(value: (napDuration - remainingTime) / napDuration)
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
            } else {
                Text("Duration: \(Int(napDuration / 60)) minutes")
                    .font(.headline)
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct WatchPreviewCard: View {
    let isConnected: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "applewatch")
                .font(.title2)
                .foregroundStyle(isConnected ? .green : .gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Watch")
                    .font(.headline)
                Text(isConnected ? "Connected" : "Not Connected")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct SoundscapePlanCard: View {
    let plan: SoundscapePlan
    
    private var planEnd: TimeInterval {
        plan.segments.map { $0.startOffset + $0.duration }.max() ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "sunrise.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Soundscape activated")
                        .font(.title3.weight(.semibold))

                    Text(plan.recommendationSummary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(plan.wakeEaseRating)
                        .font(.callout.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.systemYellow).opacity(0.25))
                        )

                    Text("Cortisol drop score \(Int(plan.cortisolReductionScore))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(plan.ambientProfile.name)
                    .font(.headline)
                Text(plan.ambientProfile.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(plan.ambientProfile.dynamicElements, id: \.self) { element in
                            Text(element.capitalized)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.blue.opacity(0.15))
                                )
                        }
                    }
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                Text("Wake-up ramp")
                    .font(.subheadline.weight(.semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)

                VStack(spacing: 12) {
                    ForEach(plan.segments) { segment in
                        SoundscapeSegmentRow(segment: segment, planEnd: planEnd)
                    }
                }
            }
        }
        .padding(22)
        .background(Color(.systemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color(.systemYellow).opacity(0.25))
        )
    }
}

struct SoundscapeSegmentRow: View {
    let segment: SoundscapeSegment
    let planEnd: TimeInterval

    private var minutesUntilWake: Int {
        let minutes = max(planEnd - segment.startOffset, 0.0) / 60
        return Int(round(minutes))
    }

    private var durationText: String {
        let minutes = max(segment.duration / 60, 1.0)
        return "\(Int(round(minutes))) min"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(segment.label)
                    .font(.body.weight(.semibold))
                Text(segment.soundPalette)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(segment.coachingNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(durationText)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(.systemGray5))
                    )

                Text("T-\(minutesUntilWake)m")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(segment.intensity)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.9))
        )
    }
}

struct CustomCheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(configuration.isOn ? Color.blue : Color.secondary)

                configuration.label
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct HistoryTab: View {
    private let sessions = HistorySession.sampleData

    private var averageEfficiency: Double {
        let total = sessions.reduce(0) { $0 + $1.efficiency }
        return total / Double(sessions.count)
    }

    private var averageOptimalAdjustment: Double {
        let total = sessions.reduce(0) { $0 + Double($1.optimalWakeAdjustmentMinutes) }
        return total / Double(sessions.count)
    }

    private var totalRestedHoursThisWeek: Double {
        sessions.reduce(0) { total, session in
            let hours = session.duration / 3600
            return session.isFromCurrentWeek ? total + hours : total
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                SummaryHighlights(
                    averageEfficiency: averageEfficiency,
                    averageOptimalAdjustment: averageOptimalAdjustment,
                    totalRestedHoursThisWeek: totalRestedHoursThisWeek
                )

                VStack(alignment: .leading, spacing: 18) {
                    Text("Recent sessions")
                        .font(.title3.weight(.semibold))

                    VStack(spacing: 14) {
                        ForEach(sessions) { session in
                            NapHistoryCard(session: session)
                        }
                    }
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("History")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nap history")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text("Optimized wake-ups based on your recent sessions")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Label("Synced", systemImage: "arrow.triangle.2.circlepath.circle")
                Label("Watch insights", systemImage: "applewatch")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}

struct HistorySession: Identifiable {
    let id = UUID()
    let startDate: Date
    let duration: TimeInterval
    let optimalWakeAdjustmentMinutes: Int
    let efficiency: Double
    let restingHeartRate: Int
    let hrvScore: Int
    let cyclesCompleted: Double
    let recoveryNote: String

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: startDate)
    }

    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startDate)
    }

    var formattedDuration: String {
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var formattedEfficiency: String {
        "\(Int(efficiency * 100))%"
    }

    var cycleDescriptor: String {
        String(format: "%.1f cycles", cyclesCompleted)
    }

    var isFromCurrentWeek: Bool {
        Calendar.current.isDate(startDate, equalTo: Date(), toGranularity: .weekOfYear)
    }
}

extension HistorySession {
    static let sampleData: [HistorySession] = {
        let calendar = Calendar.current
        let now = Date()

        func date(daysAgo: Int, hour: Int, minute: Int) -> Date {
            let base = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? now
        }

        return [
            HistorySession(
                startDate: date(daysAgo: 1, hour: 13, minute: 5),
                duration: 78 * 60,
                optimalWakeAdjustmentMinutes: 6,
                efficiency: 0.92,
                restingHeartRate: 56,
                hrvScore: 63,
                cyclesCompleted: 1.3,
                recoveryNote: "Excellent recovery"
            ),
            HistorySession(
                startDate: date(daysAgo: 2, hour: 14, minute: 20),
                duration: 45 * 60,
                optimalWakeAdjustmentMinutes: 3,
                efficiency: 0.88,
                restingHeartRate: 58,
                hrvScore: 61,
                cyclesCompleted: 0.9,
                recoveryNote: "Good rest"
            ),
            HistorySession(
                startDate: date(daysAgo: 3, hour: 15, minute: 10),
                duration: 60 * 60,
                optimalWakeAdjustmentMinutes: 8,
                efficiency: 0.95,
                restingHeartRate: 54,
                hrvScore: 65,
                cyclesCompleted: 1.2,
                recoveryNote: "Very refreshing"
            )
        ]
    }()
}

// MARK: - Missing Tab Views

struct AnalyticsTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Analytics")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .padding(.horizontal, 20)
                
                Text("Sleep analytics and insights coming soon")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Analytics")
    }
}

struct SettingsTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .padding(.horizontal, 20)
                
                Text("App settings and preferences coming soon")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Settings")
    }
}

struct SummaryHighlights: View {
    let averageEfficiency: Double
    let averageOptimalAdjustment: Double
    let totalRestedHoursThisWeek: Double
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                SummaryCard(
                    title: "Avg Efficiency",
                    value: "\(Int(averageEfficiency * 100))%",
                    icon: "chart.line.uptrend.xyaxis"
                )
                
                SummaryCard(
                    title: "Optimal Adjustment",
                    value: "\(Int(averageOptimalAdjustment))m",
                    icon: "clock.arrow.circlepath"
                )
            }
            
            SummaryCard(
                title: "Weekly Rest Hours",
                value: "\(String(format: "%.1f", totalRestedHoursThisWeek))h",
                icon: "moon.zzz.fill"
            )
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.blue)
                Spacer()
            }
            
            Text(value)
                .font(.title2.weight(.bold))
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct NapHistoryCard: View {
    let session: HistorySession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.formattedDate)
                        .font(.headline)
                    Text("\(session.formattedStartTime) • \(session.formattedDuration)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(session.formattedEfficiency)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.green)
                    Text("efficiency")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack(spacing: 16) {
                Label("\(session.restingHeartRate) BPM", systemImage: "heart.fill")
                Label("HRV \(session.hrvScore)", systemImage: "waveform.path.ecg")
                Label(session.cycleDescriptor, systemImage: "moon.circle.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            if session.optimalWakeAdjustmentMinutes != 0 {
                Text("Woke \(abs(session.optimalWakeAdjustmentMinutes))m \(session.optimalWakeAdjustmentMinutes > 0 ? "after" : "before") optimal time")
                    .font(.footnote)
                    .foregroundStyle(session.optimalWakeAdjustmentMinutes > 0 ? .orange : .green)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill((session.optimalWakeAdjustmentMinutes > 0 ? Color.orange : Color.green).opacity(0.1))
                    )
            }
            
            Text(session.recoveryNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    ContentView()
}

// MARK: - Soundscape Models

struct SoundscapePlan: Identifiable {
    let id = UUID()
    let recommendationSummary: String
    let wakeEaseRating: String
    let cortisolReductionScore: Double
    let ambientProfile: AmbientProfile
    let segments: [SoundscapeSegment]
}

struct AmbientProfile {
    let name: String
    let description: String
    let dynamicElements: [String]
}

struct SoundscapeSegment: Identifiable {
    let id = UUID()
    let label: String
    let soundPalette: String
    let coachingNote: String
    let startOffset: TimeInterval
    let duration: TimeInterval
    let intensity: String
}

class SoundscapeService: ObservableObject {
    static let shared = SoundscapeService()
    
    private init() {}
    
    func generatePlan(napDuration: TimeInterval, biometrics: SleepBiometrics) -> SoundscapePlan {
        let ambientProfile = AmbientProfile(
            name: "Gentle Morning",
            description: "Soft nature sounds with gradual volume increase",
            dynamicElements: ["birds", "water", "wind"]
        )
        
        let segments = [
            SoundscapeSegment(
                label: "Pre-wake",
                soundPalette: "Soft nature",
                coachingNote: "Preparing your mind for gentle awakening",
                startOffset: napDuration - 300,
                duration: 180,
                intensity: "Low"
            ),
            SoundscapeSegment(
                label: "Wake transition",
                soundPalette: "Melodic tones",
                coachingNote: "Gradually increasing awareness",
                startOffset: napDuration - 120,
                duration: 120,
                intensity: "Medium"
            )
        ]
        
        return SoundscapePlan(
            recommendationSummary: "Optimized for your current biometrics",
            wakeEaseRating: "Gentle",
            cortisolReductionScore: 85.0,
            ambientProfile: ambientProfile,
            segments: segments
        )
    }
}
