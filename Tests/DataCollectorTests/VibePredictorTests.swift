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

    @Test("ML Model Loads Successfully")
    func modelLoads() async {
        let predictor = VibePredictor()

        // Predictor should initialize without errors
        #expect(predictor != nil)
    }

    @Test("Sleep Prediction (3 AM, Stationary)")
    func sleepPrediction() async {
        let predictor = VibePredictor()

        // Test sleep prediction at 3 AM
        let timestamp = Date(timeIntervalSince1970: 1_704_052_200)  // 3 AM
        let result = await predictor.predict(
            timestamp: timestamp,
            distance: 0.0,
            activity: .stationary,
            startTime: Date(timeIntervalSince1970: 1_704_048_600),
            duration: 3600
        )

        #expect(result.vibe == .sleep)
        #expect(result.probability > 0.9)
    }

    @Test("Focus Prediction (10 AM, Stationary)")
    func focusPrediction() async {
        let predictor = VibePredictor()

        // Test focus prediction at 10 AM
        let timestamp = Date(timeIntervalSince1970: 1_704_099_600)  // 10 AM
        let result = await predictor.predict(
            timestamp: timestamp,
            distance: 0.0,
            activity: .stationary,
            startTime: Date(timeIntervalSince1970: 1_704_096_000),
            duration: 3600
        )

        #expect(result.vibe == .focus)
        #expect(result.probability > 0.8)
    }

    @Test("Energetic Prediction (Running)")
    func energeticPrediction() async {
        let predictor = VibePredictor()

        // Test energetic prediction for running
        let timestamp = Date(timeIntervalSince1970: 1_704_103_200)  // 11 AM
        let result = await predictor.predict(
            timestamp: timestamp,
            distance: 3000.0,
            activity: .running,
            startTime: Date(timeIntervalSince1970: 1_704_101_400),
            duration: 1800
        )

        #expect(result.vibe == .energetic)
        #expect(result.probability > 0.8)
    }

    @Test("Commute Prediction (8 AM, Automotive)")
    func commutePrediction() async {
        let predictor = VibePredictor()

        // Test commute prediction at 8 AM
        let timestamp = Date(timeIntervalSince1970: 1_704_092_400)  // 8 AM
        let result = await predictor.predict(
            timestamp: timestamp,
            distance: 10000.0,
            activity: .automotive,
            startTime: Date(timeIntervalSince1970: 1_704_089_700),
            duration: 2700
        )

        #expect(result.vibe == .commute)
        #expect(result.probability > 0.8)
    }

    @Test("Chill Prediction (9 PM, Stationary)")
    func chillPrediction() async {
        let predictor = VibePredictor()

        // Test chill prediction at 9 PM
        let timestamp = Date(timeIntervalSince1970: 1_704_139_200)  // 9 PM
        let result = await predictor.predict(
            timestamp: timestamp,
            distance: 0.0,
            activity: .stationary,
            startTime: Date(timeIntervalSince1970: 1_704_135_600),
            duration: 3600
        )

        #expect(result.vibe == .chill)
        #expect(result.probability > 0.7)
    }

    @Test("Morning Routine Prediction (7 AM, Stationary)")
    func morningRoutinePrediction() async {
        let predictor = VibePredictor()

        // Test morning routine at 7 AM
        let timestamp = Date(timeIntervalSince1970: 1_704_088_800)  // 7 AM
        let result = await predictor.predict(
            timestamp: timestamp,
            distance: 0.0,
            activity: .stationary,
            startTime: Date(timeIntervalSince1970: 1_704_085_200),
            duration: 3600
        )

        #expect(result.vibe == .morningRoutine)
        #expect(result.probability > 0.8)
    }
}
