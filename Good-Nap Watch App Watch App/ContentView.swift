//
//  ContentView.swift
//  Good-Nap Watch App Watch App
//
//  Created by AI Club on 10/30/25.
//

import SwiftUI

struct ContentView: View {
    @State private var remainingTime: TimeInterval = 600 // 10 minutes default
    @State private var totalDuration: TimeInterval = 600
    @State private var isActive = true
    @State private var timer: Timer?
    
    // Biometric data
    @State private var heartRate: Int = 65
    @State private var oxygenSaturation: Int = 98
    @State private var respirationRate: Double = 13.5
    @State private var hrvScore: Int = 58
    @State private var biometricTimer: Timer?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            ZStack {
                LinearGradient(colors: [Color.indigo.opacity(0.25), Color.black.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        Text("NapSync")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)

                        timerView

                        dataCollectionIndicator

                        biometricDataView

                        Spacer()
                    }
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                }
            }
        }
        .onAppear {
            startTimer()
            startBiometricTimer()
        }
        .onDisappear {
            stopTimer()
            stopBiometricTimer()
        }
    }

    private var timerView: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.mint.opacity(0.2), lineWidth: 6)
                    .frame(width: 120, height: 120)

                // Progress ring
                Circle()
                    .trim(from: 0, to: min(1.0 - (remainingTime / totalDuration), 1.0))
                    .stroke(Color.mint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                // Center time display
                VStack(spacing: 4) {
                    Text(formatTime(remainingTime))
                        .font(.title2)
                        .monospacedDigit()
                        .foregroundStyle(.mint)
                    Text("remaining")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Time Left")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var dataCollectionIndicator: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(.mint)

            Text("Collecting biometric data")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.mint.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var biometricDataView: some View {
        VStack(spacing: 8) {
            Text("Biometric Data")
                .font(.headline)
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                // Heart Rate Panel
                biometricPanel(
                    icon: "heart.fill",
                    title: "Heart Rate",
                    value: "\(heartRate)",
                    unit: "BPM",
                    color: .red
                )
                
                // Oxygen Saturation Panel
                biometricPanel(
                    icon: "o2.circle.fill",
                    title: "Oxygen Saturation",
                    value: "\(oxygenSaturation)",
                    unit: "%",
                    color: .cyan
                )
                
                // Respiration Rate Panel
                biometricPanel(
                    icon: "lungs.fill",
                    title: "Respiration Rate",
                    value: String(format: "%.1f", respirationRate),
                    unit: "breaths/min",
                    color: .green
                )
                
                // HRV Score Panel
                biometricPanel(
                    icon: "waveform.path.ecg",
                    title: "HRV Score",
                    value: "\(hrvScore)",
                    unit: "ms",
                    color: .blue
                )
            }
        }
    }
    
    private func biometricPanel(icon: String, title: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(color)
                .frame(width: 20)
            
            // Title and Value
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.callout)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.gray.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingTime > 0 {
                remainingTime -= 1
            } else {
                stopTimer()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func startBiometricTimer() {
        biometricTimer?.invalidate()
        biometricTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            // Update biometric data with very small realistic fluctuations
            heartRate += Int.random(in: -2...2)
            heartRate = max(60, min(75, heartRate)) // Keep within realistic range
            
            oxygenSaturation += Int.random(in: -1...1)
            oxygenSaturation = max(96, min(100, oxygenSaturation))
            
            respirationRate += Double.random(in: -0.5...0.5)
            respirationRate = max(12.0, min(16.0, respirationRate))
            
            hrvScore += Int.random(in: -3...3)
            hrvScore = max(45, min(70, hrvScore))
        }
    }

    private func stopBiometricTimer() {
        biometricTimer?.invalidate()
        biometricTimer = nil
    }
}

#Preview {
    ContentView()
}
