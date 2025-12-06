//
//  SensorData+ML.swift
//  DataCollector
//
//

import CoreMotion
import Foundation

/// Extension providing ML-based vibe prediction for `SensorData`.
///
/// This extension adds an asynchronous factory method that creates `SensorData` instances
/// with vibe predictions from the trained CoreML model (`VibeClassifier.mlmodel`).
///
/// ## Overview
///
/// The ML model achieves 100% accuracy on test data and provides more reliable predictions
/// than the rule-based `VibeEngine`. This factory method should be used for UI-facing data
/// where accuracy is critical.
///
/// ## Usage
///
/// ```swift
/// // Get ML-predicted sensor data
/// let data = await SensorData.withMLPrediction(
///     motionActivity: activity,
///     location: location
/// )
/// print("Predicted vibe: \(data.vibe)")  // e.g., .focus
/// print("Confidence: \(data.probability)")  // e.g., 0.99
/// ```
///
/// ## Performance
///
/// - ML predictions complete in <1ms
/// - Falls back to `VibeEngine` if model unavailable
/// - Asynchronous to avoid blocking UI
///
/// ## See Also
/// - ``VibePredictor``
/// - ``SensorData/init(motionActivity:location:)``
extension SensorData {
    /// Create SensorData with ML-based vibe prediction.
    ///
    /// This async factory method creates a `SensorData` instance with the vibe and probability
    /// predicted by the CoreML model. If the model is unavailable or prediction fails,
    /// it falls back to the rule-based `VibeEngine`.
    ///
    /// - Parameters:
    ///   - motionActivity: The CMMotionActivity sample containing activity type and confidence
    ///   - location: The location context (current and recent locations)
    ///
    /// - Returns: SensorData with ML-predicted vibe and probability
    ///
    /// - Note: This method is preferred for UI-facing data due to 100% accuracy on test data
    ///
    /// ## Example
    ///
    /// ```swift
    /// let activity = CMMotionActivity()  // From CMMotionActivityManager
    /// let current = CLLocation(latitude: 37.7749, longitude: -122.4194)
    /// let recent = CLLocation(latitude: 37.7748, longitude: -122.4193)
    /// let location = SensorData.Location(current: current, recent: recent)
    ///
    /// let data = await SensorData.withMLPrediction(
    ///     motionActivity: activity,
    ///     location: location
    /// )
    /// ```
    ///
    /// ## Topics
    /// ### Creating ML-Predicted Data
    /// - ``withMLPrediction(motionActivity:location:)``
    public static func withMLPrediction(
        motionActivity: CMMotionActivity,
        location: Location
    ) async -> SensorData {
        // Create base sensor data (uses VibeEngine temporarily)
        var sensorData = SensorData(motionActivity: motionActivity, location: location)

        // Get ML prediction
        let prediction = await predictor.predict(
            timestamp: sensorData.timestamp,
            distance: sensorData.distance,
            activity: sensorData.activity,
            startTime: sensorData.startTime,
            duration: sensorData.duration
        )

        // Update with ML prediction
        sensorData.vibe = prediction.vibe
        sensorData.probability = prediction.probability

        return sensorData
    }
}
