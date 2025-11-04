//
//  BiometricData.swift
//  Good-Nap
//
//  Created by AI on 11/3/25.
//

import Foundation

struct SleepBiometrics {
    let restingHeartRate: Int
    let heartRateVariability: Int
    let respiratoryRate: Double
    let microMovementIndex: Double
    
    init(restingHeartRate: Int, heartRateVariability: Int, respiratoryRate: Double, microMovementIndex: Double) {
        self.restingHeartRate = restingHeartRate
        self.heartRateVariability = heartRateVariability
        self.respiratoryRate = respiratoryRate
        self.microMovementIndex = microMovementIndex
    }
}
