import SwiftUI
import NapSyncShared

struct EnhancedFeedbackView: View {
    @Binding var feedback: DetailedNapFeedback
    let onSubmit: (DetailedNapFeedback) -> Void
    @State private var showingAdditionalQuestions = false
    
    var body: some View {
        VStack(spacing: 25) {
            Text("How was your nap?")
                .font(.title2)
                .fontWeight(.semibold)
            
            // Quality Rating
            VStack(spacing: 15) {
                Text("Overall Quality")
                    .font(.headline)
                
                HStack(spacing: 15) {
                    ForEach(1...5, id: \.self) { index in
                        Button(action: {
                            feedback.qualityRating = index
                        }) {
                            Image(systemName: index <= feedback.qualityRating ? "star.fill" : "star")
                                .font(.title2)
                                .foregroundColor(index <= feedback.qualityRating ? .yellow : .gray)
                        }
                    }
                }
            }
            
            // Post-Nap Feeling
            VStack(spacing: 15) {
                Text("How do you feel?")
                    .font(.headline)
                
                Picker("Feeling", selection: $feedback.postNapFeeling) {
                    ForEach(PostNapFeeling.allCases, id: \.self) { feeling in
                        Text(feeling.displayName).tag(feeling)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Wake Time Satisfaction
            VStack(spacing: 15) {
                Text("Was the wake time optimal?")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    Button("Too Early") {
                        feedback.wakeTimeFeedback = .tooEarly
                    }
                    .foregroundColor(feedback.wakeTimeFeedback == .tooEarly ? .white : .blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(feedback.wakeTimeFeedback == .tooEarly ? Color.blue : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.blue))
                    .cornerRadius(8)
                    
                    Button("Perfect") {
                        feedback.wakeTimeFeedback = .perfect
                    }
                    .foregroundColor(feedback.wakeTimeFeedback == .perfect ? .white : .green)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(feedback.wakeTimeFeedback == .perfect ? Color.green : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green))
                    .cornerRadius(8)
                    
                    Button("Too Late") {
                        feedback.wakeTimeFeedback = .tooLate
                    }
                    .foregroundColor(feedback.wakeTimeFeedback == .tooLate ? .white : .red)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(feedback.wakeTimeFeedback == .tooLate ? Color.red : Color.clear)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red))
                    .cornerRadius(8)
                }
            }
            
            // Additional Questions Toggle
            Button("Additional Feedback") {
                showingAdditionalQuestions.toggle()
            }
            .font(.subheadline)
            .foregroundColor(.blue)
            
            if showingAdditionalQuestions {
                AdditionalFeedbackView(feedback: $feedback)
            }
            
            // Submit Button
            Button("Submit Feedback") {
                onSubmit(feedback)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!feedback.isComplete)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

struct AdditionalFeedbackView: View {
    @Binding var feedback: DetailedNapFeedback
    
    var body: some View {
        VStack(spacing: 20) {
            // Sleep Quality Factors
            VStack(alignment: .leading, spacing: 10) {
                Text("What affected your sleep quality?")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 10) {
                    ForEach(SleepQualityFactor.allCases, id: \.self) { factor in
                        Button(factor.displayName) {
                            if feedback.sleepQualityFactors.contains(factor) {
                                feedback.sleepQualityFactors.removeAll { $0 == factor }
                            } else {
                                feedback.sleepQualityFactors.append(factor)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(feedback.sleepQualityFactors.contains(factor) ? .white : .blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(feedback.sleepQualityFactors.contains(factor) ? Color.blue : Color.clear)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue))
                        .cornerRadius(6)
                    }
                }
            }
            
            // Pre-nap state
            VStack(alignment: .leading, spacing: 10) {
                Text("How did you feel before the nap?")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Picker("Pre-nap state", selection: $feedback.preNapState) {
                    ForEach(PreNapState.allCases, id: \.self) { state in
                        Text(state.displayName).tag(state)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            
            // Environment quality
            VStack(spacing: 10) {
                Text("Environment Quality (1-5)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    ForEach(1...5, id: \.self) { rating in
                        Button("\(rating)") {
                            feedback.environmentQuality = rating
                        }
                        .frame(width: 40, height: 40)
                        .background(feedback.environmentQuality == rating ? Color.blue : Color(.systemGray5))
                        .foregroundColor(feedback.environmentQuality == rating ? .white : .primary)
                        .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.top, 10)
    }
}

// MARK: - Enhanced Feedback Model

struct DetailedNapFeedback {
    var qualityRating: Int = 3
    var postNapFeeling: PostNapFeeling = .refreshed
    var wakeTimeFeedback: WakeTimeFeedback = .perfect
    var sleepQualityFactors: [SleepQualityFactor] = []
    var preNapState: PreNapState = .normal
    var environmentQuality: Int = 3
    
    var isComplete: Bool {
        return qualityRating > 0 && wakeTimeFeedback != .unknown
    }
    
    func toNapFeedback(session: NapSession, biometrics: [BiometricDataPoint]) -> NapFeedback {
        return NapFeedback(
            napSession: session,
            qualityRating: qualityRating,
            postNapFeeling: postNapFeeling,
            sessionBiometrics: biometrics,
            wasWakeTimeOptimal: wakeTimeFeedback == .perfect,
            timestamp: Date()
        )
    }
}

enum WakeTimeFeedback {
    case tooEarly
    case perfect
    case tooLate
    case unknown
}

enum SleepQualityFactor: String, CaseIterable {
    case noise = "noise"
    case temperature = "temperature" 
    case light = "light"
    case stress = "stress"
    case caffeine = "caffeine"
    case comfort = "comfort"
    case interruption = "interruption"
    case none = "none"
    
    var displayName: String {
        switch self {
        case .noise: return "Noise"
        case .temperature: return "Temperature"
        case .light: return "Light"
        case .stress: return "Stress"
        case .caffeine: return "Caffeine"
        case .comfort: return "Comfort"
        case .interruption: return "Interruption"
        case .none: return "Nothing"
        }
    }
}

enum PreNapState: String, CaseIterable {
    case veryTired = "very_tired"
    case tired = "tired"
    case normal = "normal"
    case alert = "alert"
    
    var displayName: String {
        switch self {
        case .veryTired: return "Very Tired"
        case .tired: return "Tired"
        case .normal: return "Normal"
        case .alert: return "Alert"
        }
    }
}

#Preview {
    EnhancedFeedbackView(
        feedback: .constant(DetailedNapFeedback()),
        onSubmit: { _ in }
    )
}