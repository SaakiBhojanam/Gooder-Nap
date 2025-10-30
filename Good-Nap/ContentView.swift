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

class MockHomeViewModel: ObservableObject {
    @Published var napDuration: TimeInterval = 1800 // 30 minutes
    @Published var isNapping = false
}

// MARK: - Minimal ML stubs to make this file compile standalone

@MainActor
final class MLModelService: ObservableObject {
    static let shared = MLModelService()

    @Published var isModelTrained: Bool = false

    func initializeMLModels() {
        // No-op stub for standalone build.
        // In your app, kick off model loading/training here.
    }
}

struct MLTrainingView: View {
    @EnvironmentObject var mlModelService: MLModelService

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 64))
            Text("Training your sleep model…")
                .font(.title3.weight(.semibold))
            Text("This is a placeholder training screen so the sample compiles.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button {
                // Simulate training completion
                mlModelService.isModelTrained = true
            } label: {
                Text("Finish Training")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor, in: Capsule())
            }
            .padding(.horizontal, 24)
        }
        .padding()
        .navigationTitle("Model Training")
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
    @EnvironmentObject var homeViewModel: MockHomeViewModel
    @EnvironmentObject var mlModelService: MLModelService
    @EnvironmentObject var watchConnectivityManager: MockWatchConnectivityManager

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
                        isModelTrained: mlModelService.isModelTrained
                    )

                    WatchPreviewCard(isConnected: watchConnectivityManager.isConnected)

                    controlPanel

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

            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    homeViewModel.isNapping.toggle()
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
        .background(Color(.systemBackground).opacity(0.85), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }
}

struct HistoryTab: View {
    private let sessions = NapSession.sampleData

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

struct NapSession: Identifiable {
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

extension NapSession {
    static let sampleData: [NapSession] = {
        let calendar = Calendar.current
        let now = Date()

        func date(daysAgo: Int, hour: Int, minute: Int) -> Date {
            let base = calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
            return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: base) ?? now
        }

        return [
            NapSession(
                startDate: date(daysAgo: 1, hour: 13, minute: 5),
                duration: 78 * 60,
                optimalWakeAdjustmentMinutes: 6,
                efficiency: 0.92,
                restingHeartRate: 56,
                hrvScore: 63,
                cyclesCompleted: 1.3,
                recoveryNote: "Woke at light sleep peak • felt clear within 2 min"
            ),
            NapSession(
                startDate: date(daysAgo: 3, hour: 14, minute: 40),
                duration: 90 * 60,
                optimalWakeAdjustmentMinutes: 12,
                efficiency: 0.88,
                restingHeartRate: 58,
                hrvScore: 57,
                cyclesCompleted: 1.5,
                recoveryNote: "REM exit detected early • wake-up eased grogginess"
            ),
            NapSession(
                startDate: date(daysAgo: 5, hour: 12, minute: 20),
                duration: 65 * 60,
                optimalWakeAdjustmentMinutes: 4,
                efficiency: 0.95,
                restingHeartRate: 54,
                hrvScore: 68,
                cyclesCompleted: 1.1,
                recoveryNote: "Short recovery nap • high HRV rebound"
            ),
            NapSession(
                startDate: date(daysAgo: 8, hour: 16, minute: 10),
                duration: 84 * 60,
                optimalWakeAdjustmentMinutes: 9,
                efficiency: 0.9,
                restingHeartRate: 57,
                hrvScore: 60,
                cyclesCompleted: 1.4,
                recoveryNote: "Motion spike from phone check • algorithm re-synced"
            ),
            NapSession(
                startDate: date(daysAgo: 11, hour: 15, minute: 0),
                duration: 72 * 60,
                optimalWakeAdjustmentMinutes: 5,
                efficiency: 0.93,
                restingHeartRate: 55,
                hrvScore: 65,
                cyclesCompleted: 1.2,
                recoveryNote: "Breathing steadied quickly • woke to gentle haptics"
            )
        ]
    }()
}

struct SummaryHighlights: View {
    let averageEfficiency: Double
    let averageOptimalAdjustment: Double
    let totalRestedHoursThisWeek: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This week")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                SummaryTile(
                    title: "Avg efficiency",
                    value: "\(Int(averageEfficiency * 100))%",
                    caption: "Aligned with circadian rhythm"
                )

                SummaryTile(
                    title: "Wake adjustment",
                    value: "\(Int(averageOptimalAdjustment)) min",
                    caption: "Model shift before alarm"
                )
            }

            SummaryTile(
                title: "Rested time",
                value: String(format: "%.1f h", totalRestedHoursThisWeek),
                caption: "Optimized naps this week"
            )
        }
        .padding(22)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2))
        )
    }
}

struct SummaryTile: View {
    let title: String
    let value: String
    let caption: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.headline)

            Text(caption)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

struct NapHistoryCard: View {
    let session: NapSession

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.formattedDate)
                    .font(.headline)
                Spacer()
                Text(session.formattedDuration)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Label(session.formattedStartTime, systemImage: "clock")
                Label("\(session.restingHeartRate) bpm", systemImage: "heart.fill")
                Label("HRV \(session.hrvScore)", systemImage: "waveform.path.ecg")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Divider()

            HStack(spacing: 18) {
                MetricPill(title: "Efficiency", value: session.formattedEfficiency, color: .green)
                MetricPill(title: "Cycles", value: session.cycleDescriptor, color: .blue)
                MetricPill(title: "Wake shift", value: "\(session.optimalWakeAdjustmentMinutes)m", color: .purple)
            }

            Text(session.recoveryNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1))
        )
    }
}

struct MetricPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
    }
}

struct NapCycleTrackerView: View {
    struct Segment: Identifiable {
        let id = UUID()
        let title: String
        let ratio: Double
        let color: Color
        let systemIcon: String
    }

    private struct SegmentRange: Identifiable {
        let id = UUID()
        let segment: Segment
        let start: Double
        let end: Double
    }

    let napDuration: TimeInterval
    let isNapping: Bool
    let isModelTrained: Bool

    private var segments: [Segment] {
        [
            Segment(title: "Light", ratio: 0.32, color: Color.cyan, systemIcon: "cloud.moon.fill"),
            Segment(title: "Deep", ratio: 0.26, color: Color.blue, systemIcon: "moon.zzz.fill"),
            Segment(title: "REM", ratio: 0.24, color: Color.purple, systemIcon: "sparkles"),
            Segment(title: "Wake", ratio: 0.18, color: Color.pink, systemIcon: "sunrise.fill")
        ]
    }

    private var segmentRanges: [SegmentRange] {
        var current: Double = 0
        return segments.map { segment in
            let end = current + segment.ratio
            defer { current = end }
            return SegmentRange(segment: segment, start: current, end: end)
        }
    }

    private var optimalWakeMinutes: Int {
        let minutes = napDuration / 60
        let wakeOffset = minutes * 0.88
        return max(10, Int(wakeOffset.rounded()))
    }

    private var cycleCount: Int {
        max(1, Int(ceil(napDuration / (90 * 60))))
    }

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(.linearGradient(colors: [Color(.systemBackground), Color(.systemBackground).opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 250, height: 250)
                    .shadow(color: Color(.systemGray4), radius: 24, x: 0, y: 18)

                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 24)
                    .frame(width: 250, height: 250)

                ForEach(segmentRanges) { range in
                    Circle()
                        .trim(from: range.start, to: range.end)
                        .stroke(
                            AngularGradient(colors: [range.segment.color.opacity(0.6), range.segment.color], center: .center),
                            style: StrokeStyle(lineWidth: 22, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 250, height: 250)
                        .overlay(
                            Circle()
                                .trim(from: range.start, to: range.end)
                                .stroke(range.segment.color.opacity(0.25), lineWidth: 2)
                                .rotationEffect(.degrees(-90))
                                .frame(width: 260, height: 260)
                        )
                }

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 160, height: 160)
                    .overlay(
                        VStack(spacing: 8) {
                            Text(isNapping ? "Optimal wake window" : "Ready for next nap")
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text("≈ \(optimalWakeMinutes) min")
                                .font(.system(size: 36, weight: .bold, design: .rounded))

                            Capsule()
                                .fill(isModelTrained ? Color.green.opacity(0.85) : Color.orange.opacity(0.85))
                                .frame(width: 108, height: 28)
                                .overlay(
                                    HStack(spacing: 6) {
                                        Image(systemName: isModelTrained ? "cpu.fill" : "bolt.horizontal.circle")
                                        Text(isModelTrained ? "Adaptive" : "Calibrating")
                                    }
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                )
                        }
                    )

                Circle()
                    .strokeBorder(Color.white.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 162, height: 162)
            }
            .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cycles planned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(cycleCount) cycle\(cycleCount > 1 ? "s" : "")")
                        .font(.headline)
                }

                Divider()
                    .frame(height: 40)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Next wake target")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(isNapping ? "Calculating in real time" : "Will adapt when nap starts")
                        .font(.headline)
                        .foregroundStyle(isNapping ? .primary : .secondary)
                }

                Spacer()
            }

            PhaseLegend(segments: segments)
        }
        .padding(24)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18))
        )
    }
}

struct PhaseLegend: View {
    let segments: [NapCycleTrackerView.Segment]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Nap cycle flow")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(segments) { segment in
                    HStack(spacing: 6) {
                        Image(systemName: segment.systemIcon)
                            .font(.caption)
                            .foregroundStyle(segment.color)
                        Text(segment.title)
                            .font(.footnote.weight(.medium))
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(segment.color.opacity(0.12))
                    )
                }
            }
        }
    }
}

struct WatchPreviewCard: View {
    let isConnected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Apple Watch companion")
                .font(.headline)

            HStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color(.black))
                        .frame(width: 140, height: 180)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .inset(by: 4)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        )

                    VStack(spacing: 14) {
                        Text("NapSync")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.7))

                        VStack(spacing: 6) {
                            Text("Cycle active")
                                .font(.footnote.weight(.medium))
                                .foregroundColor(.white)
                            Text("REM drop in 8 min")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        }

                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom)
                            )
                            .frame(width: 90, height: 24)
                            .overlay(
                                Text("Wake window")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white)
                            )

                        HStack(spacing: 12) {
                            Label("58 bpm", systemImage: "heart.fill")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.85))

                            Circle()
                                .fill(Color.green)
                                .frame(width: 6, height: 6)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Label(isConnected ? "Connected" : "Awaiting sync", systemImage: isConnected ? "dot.radiowaves.left.and.right" : "exclamationmark.triangle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isConnected ? Color.green : Color.orange)

                    Text("Your watch detects micro-adjustments in heart rate variability to predict your wake-ready window.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Divider()

                    HStack(spacing: 12) {
                        Label("Motion AI", systemImage: "waveform.path")
                        Label("HRV", systemImage: "heart.text.square")
                        Label("O2", systemImage: "lungs.fill")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(24)
        .background(Color(.systemBackground).opacity(0.9), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15))
        )
    }
}

struct HighlightRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 42, height: 42)
                Image(systemName: icon)
                    .foregroundStyle(Color.blue)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct AnalyticsTab: View {
    private let heartRateValues: [Double] = [58, 56, 54, 52, 53, 55, 57, 60, 62, 61, 59]
    private let sleepDepthValues: [Double] = [0.2, 0.5, 0.7, 0.9, 0.85, 0.6, 0.4, 0.3, 0.45, 0.8, 0.95]
    private let motionValues: [Double] = [0.1, 0.14, 0.18, 0.12, 0.09, 0.05, 0.04, 0.07, 0.11, 0.16, 0.2]

    private var columns: [GridItem] {
        [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                Text("Analytics")
                    .font(.system(size: 32, weight: .bold, design: .rounded))

                Text("Real-time biometrics and predictive models tuned to your latest nap session.")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                AnalyticsGraphCard(
                    title: "Heart rate variability",
                    subtitle: "Averaged over the current nap window",
                    metric: "\(Int(heartRateValues.last ?? 0)) bpm",
                    changeDescription: "Stable within optimal recovery zone",
                    values: heartRateValues,
                    gradient: Gradient(colors: [.green.opacity(0.5), .green])
                )

                AnalyticsGraphCard(
                    title: "Sleep depth",
                    subtitle: "Light → Deep → REM progression",
                    metric: "REM approaching",
                    changeDescription: "Wake target recalibrated +2 min",
                    values: sleepDepthValues,
                    gradient: Gradient(colors: [.blue.opacity(0.4), .purple])
                )

                AnalyticsGraphCard(
                    title: "Micro-motion",
                    subtitle: "Watch accelerometer drift",
                    metric: "Low activity",
                    changeDescription: "Body settled • arousal unlikely",
                    values: motionValues,
                    gradient: Gradient(colors: [.cyan.opacity(0.4), .indigo])
                )

                LiveProcessingCard()

                LazyVGrid(columns: columns, spacing: 16) {
                    MetricTile(title: "Respiration", value: "12.4", unit: "breaths/min", trend: "Down 3%", color: .teal)
                    MetricTile(title: "Body temp", value: "97.8", unit: "°F", trend: "Neutral", color: .orange)
                    MetricTile(title: "HRV", value: "82", unit: "ms", trend: "Up 5%", color: .green)
                    MetricTile(title: "Recovery", value: "92", unit: "%", trend: "Peak zone", color: .purple)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 28)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Analytics")
    }
}

struct AnalyticsGraphCard: View {
    let title: String
    let subtitle: String
    let metric: String
    let changeDescription: String
    let values: [Double]
    let gradient: Gradient

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.systemBackground))

                    VStack {
                        Spacer()
                        AnalyticsLine(values: values)
                            .stroke(
                                LinearGradient(gradient: gradient, startPoint: .leading, endPoint: .trailing),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                            )
                            .frame(height: proxy.size.height * 0.6)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 18)

                        Spacer(minLength: 4)
                    }

                    VStack {
                        Spacer()
                        HStack {
                            ForEach(Array(values.enumerated()), id: \.offset) { item in
                                Circle()
                                    .fill(item.offset == values.count - 1 ? Color.primary : Color.secondary.opacity(0.2))
                                    .frame(width: item.offset == values.count - 1 ? 8 : 4)
                                if item.offset < values.count - 1 {
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal, 30)
                        .padding(.bottom, 12)
                    }
                }
            }
            .frame(height: 180)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric)
                        .font(.title3.weight(.semibold))
                    Text(changeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Label("Predictive model", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.caption.weight(.semibold))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color(.secondarySystemBackground), in: Capsule())
            }
        }
        .padding(24)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15))
        )
    }
}

struct AnalyticsLine: Shape {
    let values: [Double]

    func path(in rect: CGRect) -> Path {
        guard values.count > 1 else { return Path() }

        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let range = max(maxValue - minValue, 0.001)
        let stepX = rect.width / CGFloat(values.count - 1)

        var path = Path()
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * stepX
            let normalized = (value - minValue) / range
            let y = rect.maxY - CGFloat(normalized) * rect.height

            if index == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        return path
    }
}

struct LiveProcessingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Live data pipeline")
                    .font(.headline)
                Spacer()
                Capsule()
                    .fill(Color.green.opacity(0.85))
                    .frame(width: 70, height: 26)
                    .overlay(
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 6, height: 6)
                                .shadow(color: .white, radius: 2)
                            Text("Active")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    )
            }

            Text("Sensor fusion engine blending watch, motion, and respiratory signals in real time.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                PipelineRow(icon: "heart.fill", title: "Cardio", description: "HR + HRV smoothed over 15s window")
                PipelineRow(icon: "waveform", title: "Motion", description: "Micro-adjustments + posture drift")
                PipelineRow(icon: "wind", title: "Respiration", description: "Breath cadence + variability score")
            }
        }
        .padding(24)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12))
        )
    }
}

struct PipelineRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundStyle(Color.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color.green)
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let unit: String
    let trend: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                Text(trend)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1))
        )
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
