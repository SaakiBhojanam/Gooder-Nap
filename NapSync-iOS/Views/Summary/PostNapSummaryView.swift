import SwiftUI
import Charts
import NapSyncShared

struct PostNapSummaryView: View {
    @StateObject private var viewModel = SummaryViewModel()
    
    var body: some View {
        ScrollView {
            VStack(spacing: 25) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    
                    Text("Nap Complete!")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("ML-powered analysis ready")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)
                
                // ML Insights Section
                if let insights = viewModel.mlInsights {
                    MLInsightsView(insights: insights)
                }
                
                // Nap Summary Stats
                NapStatsView(session: viewModel.napSession)
                
                // Heart Rate Chart
                if !viewModel.heartRateData.isEmpty {
                    HeartRateChartView(data: viewModel.heartRateData)
                }
                
                // Sleep Stages Timeline
                if !viewModel.sleepStages.isEmpty {
                    SleepStagesView(stages: viewModel.sleepStages)
                }
                
                // Personalized Recommendations
                if !viewModel.personalizedRecommendations.isEmpty {
                    PersonalizedRecommendationsView(recommendations: viewModel.personalizedRecommendations)
                }
                
                // Enhanced Feedback Section
                EnhancedFeedbackView(
                    feedback: $viewModel.detailedFeedback,
                    onSubmit: { feedback in
                        Task {
                            await viewModel.submitFeedback()
                        }
                    }
                )
                
                // Action Buttons
                VStack(spacing: 15) {
                    Button("Start Another Nap") {
                        NotificationCenter.default.post(name: .returnToHome, object: nil)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    
                    Button("View ML Training Progress") {
                        // Navigate to ML training status view
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                .padding(.top, 20)
                
                Spacer(minLength: 40)
            }
            .padding()
        }
        .onAppear {
            viewModel.loadNapData()
        }
    }
}

struct MLInsightsView: View {
    let insights: MLInsights
    
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.mlBlue)
                Text("AI Insights")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
                InsightCard(
                    title: "Optimal Duration",
                    value: insights.formattedOptimalDuration,
                    icon: "clock.arrow.circlepath",
                    color: .mlBlue
                )
                
                InsightCard(
                    title: "Sleep Efficiency",
                    value: insights.formattedEfficiency,
                    icon: "chart.line.uptrend.xyaxis",
                    color: insights.efficiencyColor
                )
                
                InsightCard(
                    title: "Dominant Stage",
                    value: insights.dominantSleepStage.description,
                    icon: "brain",
                    color: .mlGreen
                )
                
                InsightCard(
                    title: "Personal Score",
                    value: insights.formattedScore,
                    icon: "star.circle",
                    color: .mlOrange
                )
            }
            
            // AI Suggestions
            if !insights.improvementSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AI Suggestions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(insights.improvementSuggestions, id: \.self) { suggestion in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(suggestion)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

struct InsightCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

struct PersonalizedRecommendationsView: View {
    let recommendations: [String]
    
    var body: some View {
        VStack(spacing: 15) {
            HStack {
                Image(systemName: "person.crop.circle.badge.checkmark")
                    .foregroundColor(.purple)
                Text("Personalized for You")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(Color.purple))
                        
                        Text(recommendation)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

struct NapStatsView: View {
    let session: NapSession?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Nap Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let session = session {
                HStack(spacing: 30) {
                    StatCard(
                        title: "Duration",
                        value: formatDuration(session.duration),
                        icon: "clock.fill",
                        color: .blue
                    )
                    
                    StatCard(
                        title: "Efficiency",
                        value: "\(Int(efficiency * 100))%",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .green
                    )
                    
                    StatCard(
                        title: "Wake Type",
                        value: session.wasOptimalWakeUsed ? "Optimal" : "Target",
                        icon: session.wasOptimalWakeUsed ? "brain.head.profile" : "alarm",
                        color: session.wasOptimalWakeUsed ? .purple : .orange
                    )
                }
            } else {
                Text("Loading nap data...")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
    
    private var efficiency: Double {
        guard let session = session else { return 0 }
        return min(1.0, session.duration / session.targetDuration)
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

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HeartRateChartView: View {
    let data: [HeartRateDataPoint]
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Heart Rate During Nap")
                .font(.headline)
                .fontWeight(.semibold)
            
            Chart(data) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Heart Rate", point.heartRate)
                )
                .foregroundStyle(.red)
            }
            .frame(height: 200)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartXAxis {
                AxisMarks { _ in
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

struct SleepStagesView: View {
    let stages: [SleepStageRecord]
    
    var body: some View {
        VStack(spacing: 15) {
            Text("Sleep Stages")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 0) {
                ForEach(stages, id: \.id) { stage in
                    Rectangle()
                        .fill(colorForStage(stage.stage))
                        .frame(height: 30)
                        .frame(maxWidth: .infinity)
                }
            }
            .cornerRadius(5)
            
            // Legend
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2)) {
                ForEach(SleepStage.allCases.filter { $0 != .unknown }, id: \.self) { stage in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(colorForStage(stage))
                            .frame(width: 12, height: 12)
                        Text(stage.description)
                            .font(.caption)
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
    
    private func colorForStage(_ stage: SleepStage) -> Color {
        switch stage {
        case .awake: return .orange
        case .lightSleep: return .green
        case .deepSleep: return .blue
        case .rem: return .purple
        case .unknown: return .gray
        }
    }
}

struct FeedbackView: View {
    @Binding var rating: Int
    @Binding var feeling: PostNapFeeling
    let onSubmit: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("How do you feel?")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Star Rating
            HStack(spacing: 10) {
                ForEach(1...5, id: \.self) { index in
                    Button(action: {
                        rating = index
                    }) {
                        Image(systemName: index <= rating ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundColor(index <= rating ? .yellow : .gray)
                    }
                }
            }
            
            // Feeling Picker
            Picker("Feeling", selection: $feeling) {
                ForEach(PostNapFeeling.allCases, id: \.self) { feeling in
                    Text(feeling.displayName).tag(feeling)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            
            Button("Submit Feedback") {
                onSubmit()
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

// MARK: - Supporting Types

struct HeartRateDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let heartRate: Double
}

enum PostNapFeeling: String, CaseIterable {
    case refreshed = "refreshed"
    case groggy = "groggy"
    case alert = "alert"
    case tired = "tired"
    
    var displayName: String {
        switch self {
        case .refreshed: return "Refreshed"
        case .groggy: return "Groggy"
        case .alert: return "Alert"
        case .tired: return "Tired"
        }
    }
}

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(.systemGray5))
            .foregroundColor(.primary)
            .cornerRadius(25)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

#Preview {
    PostNapSummaryView()
}
