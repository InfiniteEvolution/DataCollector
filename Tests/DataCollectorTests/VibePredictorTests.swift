//
//  VibePredictorTests.swift
//  DataCollectorTests
//
//  Tests for ML-based vibe prediction
//

import Foundation
import Testing

@testable import DataCollector

@Suite("VibePredictor Tests")
struct VibePredictorTests {

    @Test("VibeEngine (Rules) Prediction")
    func predictRules() async {
        let predictor = VibePredictor()
        var data = SensorData()

        // Test that the VibeEngine path updates the sensor data
        let result = await predictor.predict(ve: &data)

        #expect(data.vibe == result.vibe)
        #expect(data.probability == result.probability)

        // Ensure it produces a valid vibe ID (0-7)
        #expect(data.vibe.id >= 0)
        #expect(data.vibe.id <= 7)
    }

    @Test("ML Fallback to Rules")
    func predictMLFallback() async {
        let predictor = VibePredictor()
        var data = SensorData()

        // Even if ML model is missing in test bundle, this should satisfy the fallback requirement
        // and update the sensor data using VibeEngine.
        await predictor.predict(ml: &data)

        #expect(data.vibe.id >= 0)
        #expect(data.vibe.id <= 7)
        #expect(data.probability >= 0.0)
    }
}
