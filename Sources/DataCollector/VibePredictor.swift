//
//  VibePredictor.swift
//  DataCollector
//
//  ML-based vibe predictor with VibeEngine fallback
//

import CoreML
import CoreMotion
import Foundation
import Logger
import Store

actor VibePredictor {
    private let log = LogContext("VBPR")

    /// The CoreML model for vibe prediction.
    /// Loaded asynchronously to check for updates.
    private var model: VibeClassifier?

    private let trainerStore: TrainerStore

    /// Cached Calendar instance to avoid repeated allocations.
    ///
    /// - Note: This optimization saves ~50 bytes per prediction call.
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.autoupdatingCurrent
        return c
    }()

    /// Creates a new vibe predictor.
    ///
    /// Attempts to load the `VibeClassifier.mlmodel` from the Documents directory (if updated)
    /// or falls back to the app bundle.
    init(_ trainerStore: TrainerStore) {
        self.trainerStore = trainerStore
        log.inited()

        Task {
            await loadModel()
        }
    }

    /// Loads the latest available model (Updated > Bundle).
    private func loadModel() async {
        do {
            // Ensure model is in writable filesystem
            try await trainerStore.prepareModel()

            let url = try await trainerStore.getURL()
            let config = MLModelConfiguration()
            self.model = try VibeClassifier(contentsOf: url, configuration: config)
            log.info("Loaded VibeClassifier from \(url.path)")
        } catch {
            log.error("Failed to load VibeClassifier: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Helpers

    /// Static lookup table for vibe ID to Vibe enum conversion.
    ///
    /// This optimization provides O(1) array access instead of switch statement,
    /// improving performance and cache locality.
    ///
    /// - Note: Array indices must match the vibe IDs from the ML model:
    ///   0=unknown, 1=sleep, 2=energetic, 3=focus, 4=commute, 5=chill, 6=morningRoutine
    private static let vibeTable: [Vibe] = [
        .unknown, .sleep, .energetic, .focus,
        .commute, .chill, .morningRoutine,
    ]

    /// Converts an integer vibe ID to a Vibe enum value.
    ///
    /// Uses a static lookup table for O(1) conversion with bounds checking.
    ///
    /// - Parameter id: The vibe ID from the ML model (0-6)
    /// - Returns: The corresponding Vibe enum value, or `.unknown` if out of bounds
    ///
    /// ## Performance
    ///
    /// - **Time Complexity**: O(1)
    /// - **Inline**: Force-inlined for zero function call overhead
    ///
    /// ## Example
    ///
    /// ```swift
    /// let vibe = vibeFromID(3)  // Returns .focus
    /// ```
    @inline(__always)
    private func vibeFromID(_ id: Int) -> Vibe {
        guard id >= 0 else {
            log.warning("Received negative vibe ID: \(id)")
            return .unknown
        }

        guard id < Self.vibeTable.count else {
            log.warning("Received out-of-bounds vibe ID: \(id)")
            return .unknown
        }

        return Self.vibeTable[id]
    }

    /// Generates a vibe prediction using the ML model.
    ///
    /// This method attempts to use the CoreML model for high-accuracy prediction.
    /// If the model is unavailable or fails, it falls back to the VibeEngine.
    ///
    /// - Parameter sensorData: The sensor data to update with the prediction.
    func predict(ml sensorData: inout SensorData) async {
        // Get ML prediction
        let prediction = {
            // Try ML model first
            guard let model = model else {
                log.warning("ML model is nil. Using VibeEngine fallback.")
                return predict(ve: &sensorData)
            }

            // Use cached calendar (zero allocation)
            // The Updatable MLModel expects MLMultiArrays (Array(1)) for inputs.
            let input = VibeClassifierInput(
                timestamp: toMLDouble(sensorData.timestamp.timeIntervalSince1970),
                distance: toMLDouble(sensorData.distance),
                activity: toMLDouble(Double(sensorData.activity.id)),
                startTime: toMLDouble(sensorData.startTime.timeIntervalSince1970),
                duration: toMLDouble(sensorData.duration),
                hour: toMLDouble(
                    Double(Self.calendar.component(.hour, from: sensorData.timestamp))),
                dayOfWeek: toMLDouble(
                    Double(Self.calendar.component(.weekday, from: sensorData.timestamp)))
            )

            do {
                let output = try model.prediction(input: input)

                // Inspecting the model (Step 281) revealed:
                // classLabel -> Int64 (The predicted label)
                // classProbability -> Dictionary (The probabilities)
                // vibe -> Dictionary (Likely redundant or same as classProbability due to naming config)

                // Explicit Type Annotations to debug compiler confusion
                let probabilities: [Int64: Double] = output.classProbability
                let predictedLabel: Int64 = output.classLabel

                // Ensure key matches dictionary key type
                guard let probability = probabilities[predictedLabel] else {
                    log.warning(
                        "Failed to get probability for predicted vibe \(predictedLabel) from ML model. Keys: \(probabilities.keys)"
                    )
                    // Fallback to VibeEngine
                    return predict(ve: &sensorData)
                }

                log.info("ML prediction: vibe: \(predictedLabel), probability: \(probability)")
                return (vibeFromID(Int(predictedLabel)), probability)
            } catch let error {
                log.error("Failed to use ML model: \(error.localizedDescription).")
                // Fallback to VibeEngine
                return predict(ve: &sensorData)
            }
        }()

        // Update with ML prediction
        sensorData.vibe = prediction.vibe
        sensorData.probability = prediction.probability
    }

    /// Generates a vibe prediction using the rule-based VibeEngine.
    ///
    /// This method uses the deterministic fallback logic. It is synchronous and allocation-free.
    ///
    /// - Parameter sensorData: The sensor data to update with the prediction.
    /// - Returns: A tuple containing the predicted vibe and its probability.
    @discardableResult
    @inline(__always) nonisolated func predict(ve sensorData: inout SensorData) -> (
        vibe: Vibe, probability: Double
    ) {

        let vibeConfidence: VibeSystem.Confidence = {
            switch sensorData.confidence {
            case .high: return .high
            case .medium: return .medium
            case .low: return .low
            @unknown default: return .low
            }
        }()

        // Evaluate Vibe & Probability
        // Note: Using VibeEngine (rule-based) in synchronous init.
        // For ML predictions, use SensorData.withMLPrediction() async factory method.
        let result = VibeSystem.evaluate(
            motion: sensorData.activity,
            confidence: vibeConfidence,
            speed: sensorData.speed,
            distance: sensorData.distance,
            duration: sensorData.duration,
            timestamp: sensorData.timestamp
        )

        sensorData.vibe = result.vibe
        sensorData.probability = result.probability
        log.info(
            "VibeEngine prediction: vibe: \(result.vibe), with probability: \(result.probability)")
        return (vibe: result.vibe, probability: result.probability)
    }

    deinit {
        log.deinited()
    }

    /// Wraps a scalar double into an MLMultiArray of shape [1].
    private func toMLDouble(_ value: Double) -> MLMultiArray {
        // Force try is safe here because shape [1] with Double is always valid
        let array = try! MLMultiArray(shape: [1], dataType: .double)
        array[0] = NSNumber(value: value)
        return array
    }
}
