import SwiftUI
import NapSyncShared

struct MLTrainingView: View {
    @EnvironmentObject var mlModelService: MLModelService
    @State private var hasStartedTraining = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Header
            VStack(spacing: 15) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Setting up AI")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Training personalized sleep models for optimal nap timing")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Training Progress
            if mlModelService.isTrainingInProgress {
                VStack(spacing: 20) {
                    // Progress Ring
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 8)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .trim(from: 0, to: CGFloat(mlModelService.trainingProgress))
                            .stroke(Color.blue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .frame(width: 120, height: 120)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut, value: mlModelService.trainingProgress)
                        
                        VStack {
                            Text("\(Int(mlModelService.trainingProgress * 100))%")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text("Complete")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Training Stats
                    VStack(spacing: 8) {
                        Text("Training with \(mlModelService.trainingDataCount) data points")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if mlModelService.modelAccuracy > 0 {
                            Text("Model Accuracy: \(String(format: "%.1f%%", mlModelService.modelAccuracy * 100))")
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .fontWeight(.medium)
                        }
                    }
                }
            } else {
                // Start Training Button
                VStack(spacing: 20) {
                    Button("Start AI Training") {
                        hasStartedTraining = true
                        Task {
                            await mlModelService.initializeMLModels()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
                    
                    VStack(spacing: 8) {
                        Text("This will train AI models to:")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            FeatureRow(text: "Detect your sleep stages accurately")
                            FeatureRow(text: "Find optimal wake times")
                            FeatureRow(text: "Learn from your feedback")
                            FeatureRow(text: "Personalize recommendations")
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Technical Details (Expandable)
            if hasStartedTraining {
                TechnicalDetailsView()
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            // Auto-start training after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                if !hasStartedTraining && !mlModelService.isTrainingInProgress {
                    hasStartedTraining = true
                    Task {
                        await mlModelService.initializeMLModels()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
                .font(.caption)
            Spacer()
        }
    }
}

struct TechnicalDetailsView: View {
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 15) {
            Button(action: {
                withAnimation {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Text("Technical Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .animation(.easeInOut, value: isExpanded)
                }
            }
            .foregroundColor(.blue)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    DetailRow(title: "Sleep Stage Model", description: "Random Forest classifier with 10 features")
                    DetailRow(title: "Wake Time Model", description: "Gradient boosting for optimal timing prediction")
                    DetailRow(title: "Training Data", description: "2,000 synthetic nap sessions with realistic patterns")
                    DetailRow(title: "Personalization", description: "Continuous learning from your feedback")
                    DetailRow(title: "Privacy", description: "All processing happens on your device")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
    }
}

struct DetailRow: View {
    let title: String
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    MLTrainingView()
        .environmentObject(MLModelService.shared)
}