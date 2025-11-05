import SwiftUI
import Charts

@MainActor
struct AnalyticsDashboardTab: View {
    private let analytics = AnalyticsSnapshot.demo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                SummaryHighlights(
                    averageEfficiency: analytics.averageEfficiency,
                    averageOptimalAdjustment: analytics.averageOptimalWakeDelta,
                    totalRestedHoursThisWeek: analytics.totalRestedHours
                )

                metricGrid

                AnalyticsSectionCard(
                    title: "Efficiency trend",
                    subtitle: "Week-long view of nap quality vs. target"
                ) {
                    Chart {
                        ForEach(analytics.orderedSessions) { session in
                            LineMark(
                                x: .value("Day", session.date, unit: .day),
                                y: .value("Efficiency", session.efficiencyPercentage)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.blue.gradient)
                            .symbol(Circle())

                            PointMark(
                                x: .value("Day", session.date, unit: .day),
                                y: .value("Efficiency", session.efficiencyPercentage)
                            )
                            .annotation(position: .top) {
                                if session.isOptimal {
                                    Text("Optimal")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.green.opacity(0.15), in: Capsule())
                                }
                            }
                        }

                        RuleMark(y: .value("Target", 92))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 4]))
                            .foregroundStyle(Color.secondary)
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text("\(Int(doubleValue))%")
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    }
                    .chartYScale(domain: 70...100)
                    .frame(height: 220)
                }

                AnalyticsSectionCard(
                    title: "Optimal wake alignment",
                    subtitle: "Minutes early or late vs. predicted wake window"
                ) {
                    Chart {
                        ForEach(analytics.orderedSessions) { session in
                            BarMark(
                                x: .value("Day", session.date, unit: .day),
                                y: .value("Offset", session.optimalWakeOffsetMinutes)
                            )
                            .foregroundStyle(
                                session.optimalWakeOffsetMinutes >= 0 ? Color.orange.gradient : Color.green.gradient
                            )
                            .cornerRadius(6)
                        }

                        RuleMark(y: .value("Zero", 0))
                            .foregroundStyle(Color.secondary)
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let minutes = value.as(Double.self) {
                                    Text("\(Int(minutes))m")
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    }
                    .frame(height: 200)
                }

                AnalyticsSectionCard(
                    title: "Sleep stage composition",
                    subtitle: "Distribution of light, deep, and REM sleep"
                ) {
                    Chart {
                        ForEach(analytics.orderedSessions) { session in
                            ForEach(AnalyticsSleepStage.allCases) { stage in
                                AreaMark(
                                    x: .value("Day", session.date, unit: .day),
                                    y: .value("Share", session.stageDistribution[stage] ?? 0),
                                    stacking: .normalized
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(by: .value("Stage", stage.displayName))
                            }
                        }
                    }
                    .chartLegend(position: .bottom, spacing: 16)
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let fraction = value.as(Double.self) {
                                    Text("\(Int(fraction * 100))%")
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    }
                    .chartForegroundStyleScale(
                        domain: AnalyticsSleepStage.allCases.map { $0.displayName },
                        range: AnalyticsSleepStage.allCases.map { $0.color.gradient }
                    )
                    .frame(height: 240)
                }

                AnalyticsSectionCard(
                    title: "Nap duration & quality",
                    subtitle: "Comparing time asleep with recovery score"
                ) {
                    Chart {
                        ForEach(analytics.orderedSessions) { session in
                            BarMark(
                                x: .value("Day", session.date, unit: .day),
                                y: .value("Duration", session.duration / 60)
                            )
                            .foregroundStyle(Color.cyan.opacity(0.35))
                            .cornerRadius(8)
                        }

                        ForEach(analytics.orderedSessions) { session in
                            LineMark(
                                x: .value("Day", session.date, unit: .day),
                                y: .value("Quality", session.sleepQualityScore)
                            )
                            .interpolationMethod(.catmullRom)
                            .foregroundStyle(Color.purple)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))

                            PointMark(
                                x: .value("Day", session.date, unit: .day),
                                y: .value("Quality", session.sleepQualityScore)
                            )
                            .symbolSize(60)
                            .foregroundStyle(Color.purple)
                            .annotation(position: .top) {
                                Text("\(session.sleepQualityScore)")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.12), in: Capsule())
                            }
                        }

                        RuleMark(y: .value("Goal", 85))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 4]))
                            .foregroundStyle(Color.secondary)
                            .annotation(position: .topLeading) {
                                Text("Target score 85")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text("\(Int(doubleValue))")
                                }
                            }
                        }
                    }
                    .chartYAxisLabel("Minutes (bars) & score (line)")
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .day)) { value in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    }
                    .chartYScale(domain: 60...100)
                    .frame(height: 240)
                }

                AnalyticsSectionCard(
                    title: "Recovery readiness",
                    subtitle: "Heart rate and variability captured during naps"
                ) {
                    Chart {
                        ForEach(analytics.orderedSessions) { session in
                            PointMark(
                                x: .value("Resting HR", session.restingHeartRate),
                                y: .value("HRV", session.heartRateVariability)
                            )
                            .symbol(by: .value("Dominant stage", session.dominantStage.displayName))
                            .foregroundStyle(by: .value("Dominant stage", session.dominantStage.displayName))
                            .annotation(position: .topTrailing) {
                                if session.isRecoveryOutlier {
                                    Text(session.weekdayLabel)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.12), in: Capsule())
                                }
                            }
                        }
                    }
                    .chartForegroundStyleScale(
                        domain: AnalyticsSleepStage.allCases.map { $0.displayName },
                        range: AnalyticsSleepStage.allCases.map { $0.color.gradient }
                    )
                    .chartLegend(position: .trailing)
                    .chartXAxisLabel("Resting heart rate (BPM)")
                    .chartYAxisLabel("Heart rate variability (ms)")
                    .frame(height: 240)
                    .overlay(alignment: .topLeading) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Goal HRV ≥ \(Int(analytics.averageHRV.rounded())) ms", systemImage: "waveform")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Label("Target HR ≤ \(Int(analytics.averageRestingHeartRate.rounded())) BPM", systemImage: "heart")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                    }
                }

                AnalyticsSectionCard(
                    title: "Adaptive wake windows",
                    subtitle: "Next recommended nap wake times from the AI model"
                ) {
                    VStack(spacing: 16) {
                        ForEach(analytics.upcomingWakeWindows) { window in
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(window.dayLabel)
                                        .font(.headline)
                                    Text("Window \(window.windowLabel)")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Label("Confidence \(window.confidence)%", systemImage: "bolt.badge.clock")
                                        .font(.caption)
                                        .labelStyle(.titleAndIcon)
                                        .foregroundStyle(window.confidenceColor)
                                    Text(window.recommendation)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(window.backgroundGradient)
                            )
                        }
                    }
                }

                insightsSection
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Analytics")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analytics")
                .font(.system(size: 34, weight: .bold, design: .rounded))

            Text("Synthetic HealthKit insights for \(analytics.weekRangeDescription)")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
            AnalyticsMetricCard(
                title: "Avg HRV",
                value: "\(Int(analytics.averageHRV.rounded())) ms",
                detail: "Balanced autonomic recovery",
                systemImage: "waveform.path.ecg"
            )

            AnalyticsMetricCard(
                title: "Resting HR",
                value: "\(Int(analytics.averageRestingHeartRate.rounded())) bpm",
                detail: "\(analytics.heartRateTrendDescription)",
                systemImage: "heart.fill"
            )

            AnalyticsMetricCard(
                title: "Respiratory",
                value: String(format: "%.1f bpm", analytics.averageRespiratoryRate),
                detail: "Stable breathing cadence",
                systemImage: "lungs.fill"
            )

            AnalyticsMetricCard(
                title: "Cycles",
                value: String(format: "%.1f", analytics.averageCyclesCompleted),
                detail: "\(analytics.cycleConsistencyDescription)",
                systemImage: "moon.zzz.fill"
            )
        }
    }

    private var insightsSection: some View {
        AnalyticsSectionCard(
            title: "Highlights",
            subtitle: "Automated insights from this week's naps"
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(analytics.insights) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: insight.systemImage)
                            .font(.title3)
                            .foregroundStyle(insight.accentColor)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(insight.title)
                                .font(.headline)
                            Text(insight.detail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct AnalyticsMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.primary)

            Text(value)
                .font(.title3.weight(.bold))

            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

private struct AnalyticsSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(.separator).opacity(0.1))
        )
    }
}

private struct AnalyticsInsight: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let systemImage: String

    var accentColor: Color {
        switch systemImage {
        case "star.fill":
            return .yellow
        case "arrow.triangle.2.circlepath":
            return .blue
        case "clock.arrow.2.circlepath":
            return .orange
        default:
            return .teal
        }
    }
}

private enum AnalyticsSleepStage: String, CaseIterable, Identifiable {
    case light
    case deep
    case rem

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .deep: return "Deep"
        case .rem: return "REM"
        }
    }

    var color: Color {
        switch self {
        case .light: return Color(.systemTeal)
        case .deep: return Color(.systemIndigo)
        case .rem: return Color(.systemPink)
        }
    }
}

private struct WakeWindow: Identifiable {
    let id = UUID()
    let dayLabel: String
    let windowLabel: String
    let confidence: Int
    let recommendation: String

    var confidenceColor: Color {
        switch confidence {
        case ..<70: return .orange
        case 70..<85: return .yellow
        default: return .green
        }
    }

    var backgroundGradient: LinearGradient {
        let base: Color
        switch confidence {
        case ..<70: base = Color.orange.opacity(0.18)
        case 70..<85: base = Color.yellow.opacity(0.16)
        default: base = Color.green.opacity(0.18)
        }
        return LinearGradient(colors: [base, Color(.systemBackground)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private struct NapAnalyticsDay: Identifiable {
    let id = UUID()
    let date: Date
    let duration: TimeInterval
    let efficiency: Double
    let optimalWakeOffsetMinutes: Double
    let restingHeartRate: Int
    let heartRateVariability: Int
    let respiratoryRate: Double
    let cyclesCompleted: Double
    let stageDistribution: [AnalyticsSleepStage: Double]
    let sleepQualityScore: Int

    var efficiencyPercentage: Double { efficiency * 100 }
    var weekdayLabel: String { NapAnalyticsDay.weekdayFormatter.string(from: date) }
    var isOptimal: Bool { abs(optimalWakeOffsetMinutes) <= 3 }
    var isRecoveryOutlier: Bool { heartRateVariability >= 70 || restingHeartRate <= 54 }
    var dominantStage: AnalyticsSleepStage {
        stageDistribution.max(by: { $0.value < $1.value })?.key ?? .light
    }

    static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "EEE"
        return formatter
    }()
}

private struct AnalyticsSnapshot {
    let sessions: [NapAnalyticsDay]

    var orderedSessions: [NapAnalyticsDay] {
        sessions.sorted { $0.date < $1.date }
    }

    var averageEfficiency: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.map { $0.efficiency }.reduce(0, +) / Double(sessions.count)
    }

    var averageOptimalWakeDelta: Double {
        guard !sessions.isEmpty else { return 0 }
        let deltas = sessions.map { abs($0.optimalWakeOffsetMinutes) }
        return deltas.reduce(0, +) / Double(deltas.count)
    }

    var totalRestedHours: Double {
        sessions.reduce(0) { $0 + ($1.duration / 3600) }
    }

    var averageRestingHeartRate: Double {
        guard !sessions.isEmpty else { return 0 }
        return Double(sessions.map { $0.restingHeartRate }.reduce(0, +)) / Double(sessions.count)
    }

    var averageHRV: Double {
        guard !sessions.isEmpty else { return 0 }
        return Double(sessions.map { $0.heartRateVariability }.reduce(0, +)) / Double(sessions.count)
    }

    var averageRespiratoryRate: Double {
        guard !sessions.isEmpty else { return 0 }
        let total = sessions.map { $0.respiratoryRate }.reduce(0, +)
        return (total / Double(sessions.count)).rounded(toPlaces: 1)
    }

    var averageCyclesCompleted: Double {
        guard !sessions.isEmpty else { return 0 }
        return (sessions.map { $0.cyclesCompleted }.reduce(0, +) / Double(sessions.count)).rounded(toPlaces: 1)
    }

    var heartRateTrendDescription: String {
        guard let lowest = sessions.min(by: { $0.restingHeartRate < $1.restingHeartRate }) else { return "Stable" }
        return "Low of \(lowest.restingHeartRate) bpm on \(lowest.weekdayLabel)"
    }

    var cycleConsistencyDescription: String {
        let deviation = standardDeviation(of: sessions.map { $0.cyclesCompleted })
        if deviation < 0.1 {
            return "Highly consistent cycles"
        } else if deviation < 0.25 {
            return "Predictable rhythm"
        } else {
            return "Variable cycle length"
        }
    }

    var weekRangeDescription: String {
        guard let first = orderedSessions.first?.date, let last = orderedSessions.last?.date else { return "this week" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: first)) – \(formatter.string(from: last))"
    }

    var insights: [AnalyticsInsight] {
        guard let bestEfficiency = sessions.max(by: { $0.efficiency < $1.efficiency }),
              let calmest = sessions.min(by: { $0.restingHeartRate < $1.restingHeartRate }),
              let aligned = sessions.min(by: { abs($0.optimalWakeOffsetMinutes) < abs($1.optimalWakeOffsetMinutes) }) else {
            return []
        }

        return [
            AnalyticsInsight(
                title: "Best recovery",
                detail: "\(bestEfficiency.weekdayLabel) reached \(Int(bestEfficiency.efficiencyPercentage))% efficiency with HRV \(bestEfficiency.heartRateVariability) ms.",
                systemImage: "star.fill"
            ),
            AnalyticsInsight(
                title: "Calmest resting heart",
                detail: "Lowest resting HR was \(calmest.restingHeartRate) bpm on \(calmest.weekdayLabel).",
                systemImage: "heart.text.square"
            ),
            AnalyticsInsight(
                title: "Wake alignment",
                detail: "\(aligned.weekdayLabel) wake-up was only \(Int(abs(aligned.optimalWakeOffsetMinutes))) minutes from optimal.",
                systemImage: "clock.arrow.2.circlepath"
            )
        ]
    }

    var upcomingWakeWindows: [WakeWindow] {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEEE"

        return orderedSessions.suffix(3).enumerated().map { index, session in
            let nextDate = Calendar.current.date(byAdding: .day, value: index + 1, to: Date()) ?? Date()
            let dayLabel = dayFormatter.string(from: nextDate)
            let predictedWake = session.dateAdding(minutes: -Int(session.optimalWakeOffsetMinutes.rounded()))
            let windowStart = predictedWake.addingTimeInterval(-6 * 60)
            let windowEnd = predictedWake.addingTimeInterval(6 * 60)
            let windowLabel = "\(windowStart.formatted(date: .omitted, time: .shortened)) – \(windowEnd.formatted(date: .omitted, time: .shortened))"
            let confidence = min(98, max(62, 88 + Int.random(in: -6...6)))
            let recommendation = session.recommendationSummary
            return WakeWindow(dayLabel: dayLabel, windowLabel: windowLabel, confidence: confidence, recommendation: recommendation)
        }
    }

    static let demo: AnalyticsSnapshot = {
        let calendar = Calendar.current
        let now = calendar.startOfDay(for: Date())

        func makeDate(_ daysAgo: Int) -> Date {
            calendar.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        }

        let sessions: [NapAnalyticsDay] = [
            NapAnalyticsDay(
                date: makeDate(6).addingTimeInterval(13.5 * 3600),
                duration: 68 * 60,
                efficiency: 0.86,
                optimalWakeOffsetMinutes: -4,
                restingHeartRate: 57,
                heartRateVariability: 64,
                respiratoryRate: 12.1,
                cyclesCompleted: 1.1,
                stageDistribution: [.light: 0.5, .deep: 0.3, .rem: 0.2],
                sleepQualityScore: 78
            ),
            NapAnalyticsDay(
                date: makeDate(5).addingTimeInterval(14.0 * 3600),
                duration: 74 * 60,
                efficiency: 0.9,
                optimalWakeOffsetMinutes: -2,
                restingHeartRate: 56,
                heartRateVariability: 66,
                respiratoryRate: 12.0,
                cyclesCompleted: 1.2,
                stageDistribution: [.light: 0.48, .deep: 0.29, .rem: 0.23],
                sleepQualityScore: 82
            ),
            NapAnalyticsDay(
                date: makeDate(4).addingTimeInterval(13.75 * 3600),
                duration: 80 * 60,
                efficiency: 0.93,
                optimalWakeOffsetMinutes: 1,
                restingHeartRate: 55,
                heartRateVariability: 72,
                respiratoryRate: 11.8,
                cyclesCompleted: 1.3,
                stageDistribution: [.light: 0.46, .deep: 0.32, .rem: 0.22],
                sleepQualityScore: 88
            ),
            NapAnalyticsDay(
                date: makeDate(3).addingTimeInterval(15.1 * 3600),
                duration: 70 * 60,
                efficiency: 0.88,
                optimalWakeOffsetMinutes: 3,
                restingHeartRate: 58,
                heartRateVariability: 60,
                respiratoryRate: 12.4,
                cyclesCompleted: 1.0,
                stageDistribution: [.light: 0.54, .deep: 0.28, .rem: 0.18],
                sleepQualityScore: 76
            ),
            NapAnalyticsDay(
                date: makeDate(2).addingTimeInterval(14.25 * 3600),
                duration: 64 * 60,
                efficiency: 0.84,
                optimalWakeOffsetMinutes: -5,
                restingHeartRate: 59,
                heartRateVariability: 58,
                respiratoryRate: 12.6,
                cyclesCompleted: 0.9,
                stageDistribution: [.light: 0.55, .deep: 0.27, .rem: 0.18],
                sleepQualityScore: 72
            ),
            NapAnalyticsDay(
                date: makeDate(1).addingTimeInterval(13.9 * 3600),
                duration: 78 * 60,
                efficiency: 0.95,
                optimalWakeOffsetMinutes: -1,
                restingHeartRate: 54,
                heartRateVariability: 75,
                respiratoryRate: 11.9,
                cyclesCompleted: 1.4,
                stageDistribution: [.light: 0.44, .deep: 0.33, .rem: 0.23],
                sleepQualityScore: 90
            ),
            NapAnalyticsDay(
                date: makeDate(0).addingTimeInterval(14.5 * 3600),
                duration: 72 * 60,
                efficiency: 0.91,
                optimalWakeOffsetMinutes: 2,
                restingHeartRate: 55,
                heartRateVariability: 68,
                respiratoryRate: 12.2,
                cyclesCompleted: 1.2,
                stageDistribution: [.light: 0.47, .deep: 0.31, .rem: 0.22],
                sleepQualityScore: 84
            )
        ]

        return AnalyticsSnapshot(sessions: sessions)
    }()

    private func standardDeviation(of values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        return sqrt(variance)
    }
}

private extension NapAnalyticsDay {
    func dateAdding(minutes: Int) -> Date {
        Calendar.current.date(byAdding: .minute, value: minutes, to: date) ?? date
    }

    var recommendationSummary: String {
        if efficiency >= 0.93 {
            return "Extend window by 5 min for deeper recovery"
        } else if optimalWakeOffsetMinutes < 0 {
            return "Slightly early wake. Hold wind-down longer"
        } else {
            return "Wake matched model. Repeat hydration cues"
        }
    }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        guard places >= 0 else { return self }
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
