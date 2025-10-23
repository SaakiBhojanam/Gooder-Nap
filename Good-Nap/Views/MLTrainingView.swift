import SwiftUI

struct MLTrainingView: View {
    @EnvironmentObject var mlModelService: MLModelService
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Logo/Icon
            Image(systemName: "brain.head.profile")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .symbolEffect(.pulse, isActive: mlModelService.isTrainingInProgress)
            
            VStack(spacing: 12) {
                Text("NapSync")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Initializing AI Models")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
            
            // Training Progress
            VStack(spacing: 16) {
                // Progress Circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: mlModelService.trainingProgress)
                        .stroke(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.5), value: mlModelService.trainingProgress)
                    
                    Text("\(Int(mlModelService.trainingProgress * 100))%")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                // Status Text
                Text(mlModelService.trainingStatus)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .animation(.easeInOut, value: mlModelService.trainingStatus)
                
                // Training Details
                if mlModelService.trainingDataCount > 0 {
                    Button(action: { showingDetails.toggle() }) {
                        HStack {
                            Text("Training Details")
                            Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }
                    
                    if showingDetails {
                        VStack(alignment: .leading, spacing: 8) {
                            DetailRow(label: "Training Sessions", value: "\(mlModelService.trainingDataCount)")
                            DetailRow(label: "Data Points", value: "\(mlModelService.trainingDataCount * 30)+")
                            DetailRow(label: "Model Type", value: "Sleep Stage Classifier")
                            if mlModelService.modelAccuracy > 0 {
                                DetailRow(label: "Accuracy", value: String(format: "%.1f%%", mlModelService.modelAccuracy * 100))
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
            }
            
            // Fun Facts
            if mlModelService.isTrainingInProgress {
                VStack(spacing: 8) {
                    Text("💡 Did you know?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Our AI analyzes thousands of nap patterns to find your optimal wake times during light sleep phases.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // Progress Indicator
            if mlModelService.isTrainingInProgress {
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                            .scaleEffect(index == Int(Date().timeIntervalSince1970) % 3 ? 1.5 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.6).repeatForever(autoreverses: true).delay(Double(index) * 0.2),
                                value: mlModelService.isTrainingInProgress
                            )
                    }
                    Text("Training models...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            if !mlModelService.isModelTrained {
                mlModelService.initializeMLModels()
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

#Preview {
    MLTrainingView()
        .environmentObject(MLModelService.shared)
}