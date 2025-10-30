//
//  ContentView.swift
//  Good-Nap Watch App Watch App
//
//  Created by AI Club on 10/30/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = NapSessionViewModel()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(spacing: 12) {
                header
                progressSection
                metricsSection
                actionButtons
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .digitalCrownRotation(
            $viewModel.targetDurationMinutes,
            from: viewModel.durationBounds.lowerBound,
            through: viewModel.durationBounds.upperBound,
            by: 5,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .focusable(true)
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Good Nap")
                .font(.system(.title3, design: .rounded))
                .fontWeight(.semibold)
            Text(subtitleText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var progressSection: some View {
        ZStack {
            ProgressView(value: viewModel.progress)
                .tint(.mint)
                .scaleEffect(1.1)

            VStack(spacing: 2) {
                Text(viewModel.remainingTimeString)
                    .font(.title3)
                    .monospacedDigit()
                    .foregroundStyle(.mint)
                Text("remaining")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 90)
        .padding(8)
    }

    private var metricsSection: some View {
        VStack(spacing: 8) {
            HStack {
                metricCard(title: "Max", value: "\(Int(viewModel.targetDurationMinutes)) min")
                metricCard(title: "Elapsed", value: viewModel.elapsedTimeString)
            }
            .font(.caption)

            VStack(spacing: 4) {
                Text("Optimal window")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(viewModel.optimalWindowDescription)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                if viewModel.state == .running {
                    Text("Next wake cue in \(viewModel.optimalWakeCountdown)")
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.mint)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color.mint.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 6) {
            switch viewModel.state {
            case .idle, .completed:
                Button(action: viewModel.startNap) {
                    Label("Start Nap", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)

                if viewModel.state == .completed {
                    Button(role: .destructive, action: viewModel.resetNap) {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                }
            case .running:
                Button(role: .destructive, action: viewModel.stopNap) {
                    Label("End Early", systemImage: "stop.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Text("Digital Crown adjusts max nap length")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            case .analyzing:
                ProgressView("Analyzing sleep data…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metricCard(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .padding(6)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var subtitleText: String {
        switch viewModel.state {
        case .idle:
            return "Set your max nap length with the Crown"
        case .running:
            return "Relax – we'll nudge you at the ideal moment"
        case .analyzing:
            return "Reviewing your health metrics"
        case .completed:
            return "Nap insights ready"
        }
    }
}

#Preview {
    ContentView()
}
