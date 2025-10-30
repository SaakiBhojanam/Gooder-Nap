//
//  Good_NapTests.swift
//  Good-NapTests
//
//  Created by AI Club on 10/22/25.
//

import XCTest
@testable import Good_Nap

final class Good_NapTests: XCTestCase {

    func testTrainingDataGeneratorProducesSessions() {
        let sessions = TrainingDataGenerator.generateTrainingData(count: 5)

        XCTAssertEqual(sessions.count, 5, "Expected generator to produce requested number of sessions")
        XCTAssertTrue(sessions.allSatisfy { !$0.biometricData.isEmpty }, "Sessions should include biometric samples")
        XCTAssertTrue(sessions.allSatisfy { !$0.sleepStages.isEmpty }, "Sessions should include sleep stage records")
    }
}
