//
//  SoundscapePlan.swift
//  Good-Nap
//
//  Created by AI on 11/3/25.
//

import Foundation

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
