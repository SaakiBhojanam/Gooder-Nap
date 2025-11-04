import SwiftUI
import Charts

struct AnalyticsView: View {
    private let weeklyNapData: [DailyNapMetric] = [
        .init(day: "Mon", duration: 82, efficiency: 0.87),
        .init(day: "Tue", duration: 74, efficiency: 0.83),
        .init(day: "Wed", duration: 68, efficiency: 0.79),
        .init(day: "Thu", duration: 90, efficiency: 0.9),
        .init(day: "Fri", duration: 76, efficiency: 0.85),
        .init(day: "Sat", duration: 63, efficiency: 0.74),
        .init(day: "Sun", duration: 70, efficiency: 0.8)
    ]

    private let sleepStageBreakdown: [SleepStageDistribution] = [
        .init(stage: "Light", percentage: 42),
        .init(stage: "Deep", percentage: 31),
        .init(stage: "REM", percentage: 19),
        .init(stage: "Wake", percentage: 8)
    ]

    private let biometricsTrend: [BiometricTrend] = [
        .init(minute: 0, heartRate: 74, hrv: 48),
        .init(minute: 15, heartRate: 69, hrv: 54),
        .init(minute: 30, heartRate: 65, hrv: 58),
        .init(minute: 45, heartRate: 63, hrv: 61),
        .init(minute: 60, heartRate: 60, hrv: 65),
        .init(minute: 75, heartRate: 62, hrv: 62)
    ]

    private let recommendations: [AnalyticsRecommendation] = [
        .init(title: "Ideal Nap Window", detail: "Your most restorative naps start between 1:30-2:15 PM."),
        .init(title: "Recovery Sweet Spot", detail: "Wake target at the 75 minute mark to hit peak recovery based on your HRV trends."),
        .init(title: "Smart Prep", detail: "90 minutes after light cardio shows 12% better sleep efficiency this week."),
        .init(title: "Ambient Cues", detail: "Room temperature between 68-70°F correlates with the lowest wake-up grogginess score.")
    ]

    private let heroMetrics: [MetricSummary] = [
        .init(title: "Recovery Score", value: "82", subtitle: "+6 vs last week", color: .green),
        .init(title: "Avg Nap Length", value: "76 min", subtitle: "Target: 75 min", color: .blue),
        .init(title: "Wake Refresh", value: "92%", subtitle: "Optimal cycle exit", color: .orange)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                metricHighlights
                weeklyPerformance
                biometricsSection
                sleepStageSection
                recommendationSection
            }
            .padding(.horizontal)
            .padding(.vertical, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Analytics")
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("This Week's Performance")
                .font(.title2)
                .fontWeight(.semibold)

            Text("AI generated insights from 6 tracked naps. Updated 2h ago based on your latest HealthKit trends.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var metricHighlights: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                ForEach(heroMetrics) { metric in
                    VStack(alignment: .leading, spacing: 12) {
                        Label(metric.title, systemImage: "sparkle")
                            .font(.caption)
                            .foregroundColor(metric.color)

                        Text(metric.value)
                            .font(.system(size: 32, weight: .bold))

                        Text(metric.subtitle)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(width: 180, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
            }
        }
    }

    private var weeklyPerformance: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Weekly Recovery Curve", subtitle: "Duration vs efficiency across your last 7 naps")

            Chart {
                ForEach(weeklyNapData) { dataPoint in
                    BarMark(
                        x: .value("Day", dataPoint.day),
                        y: .value("Duration", dataPoint.duration)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.75))
                    .cornerRadius(8)

                    LineMark(
                        x: .value("Day", dataPoint.day),
                        y: .value("Efficiency", dataPoint.efficiency * 100)
                    )
                    .foregroundStyle(.purple)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Day", dataPoint.day),
                        y: .value("Efficiency", dataPoint.efficiency * 100)
                    )
                    .symbolSize(70)
                    .foregroundStyle(.purple)
                }
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartYAxisLabel("Minutes / Efficiency %", position: .leading)
            .chartLegend(.hidden)

            Divider()

            HStack(spacing: 16) {
                InsightPill(title: "Best Nap", detail: "Thu • 90 min • 90% efficient", systemImage: "arrow.up.right")
                InsightPill(title: "Needs Attention", detail: "Sat • 63 min • disrupted", systemImage: "exclamationmark.triangle")
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
    }

    private var biometricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Biometric Trends", subtitle: "Heart rate & HRV progression during your optimal nap window")

            Chart {
                ForEach(biometricsTrend) { point in
                    LineMark(
                        x: .value("Minutes", point.minute),
                        y: .value("Heart Rate", point.heartRate)
                    )
                    .foregroundStyle(.red)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Minutes", point.minute),
                        y: .value("HRV", point.hrv)
                    )
                    .foregroundStyle(.blue.opacity(0.2))
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Minutes", point.minute),
                        y: .value("HRV", point.hrv)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 220)
            .chartYAxisLabel("BPM / ms", position: .leading)

            VStack(alignment: .leading, spacing: 8) {
                InsightPill(title: "Cycle Trigger", detail: "HRV peaks at 60 min signalling ideal wake window", systemImage: "bell")
                InsightPill(title: "Calm Onset", detail: "Heart rate drops 14 BPM within the first 20 minutes", systemImage: "heart")
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
    }

    private var sleepStageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Sleep Stage Composition", subtitle: "Average distribution across last 5 naps")

            HStack(alignment: .bottom, spacing: 16) {
                ForEach(sleepStageBreakdown) { stage in
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(stage.color)
                            .frame(width: 50, height: CGFloat(stage.percentage) * 2)
                            .overlay(
                                Text("\(stage.percentage)%")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(4),
                                alignment: .top
                            )

                        Text(stage.stage)
                            .font(.footnote)
                            .fontWeight(.medium)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            Divider()

            Text("Deep sleep increased 9% this week after consistent wind-down breathing routines.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
    }

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "Actionable Insights", subtitle: "Adjustments based on your AI nap coach")

            ForEach(recommendations) { recommendation in
                VStack(alignment: .leading, spacing: 6) {
                    Text(recommendation.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(recommendation.detail)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Supporting Models

private struct DailyNapMetric: Identifiable {
    let id = UUID()
    let day: String
    let duration: Double
    let efficiency: Double
}

private struct SleepStageDistribution: Identifiable {
    let id = UUID()
    let stage: String
    let percentage: Int

    var color: Color {
        switch stage {
        case "Deep": return .indigo
        case "REM": return .mint
        case "Light": return .teal
        case "Wake": return .gray
        default: return .blue
        }
    }
}

private struct BiometricTrend: Identifiable {
    let id = UUID()
    let minute: Int
    let heartRate: Double
    let hrv: Double
}

private struct AnalyticsRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
}

private struct MetricSummary: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let subtitle: String
    let color: Color
}

private struct InsightPill: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundColor(.accentColor)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor.opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                Text(detail)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(10)
        .background(
            Capsule()
                .fill(Color(.tertiarySystemGroupedBackground))
        )
    }
}

#Preview {
    NavigationView {
        AnalyticsView()
    }
}
