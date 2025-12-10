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
import Trainer

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
    private let locationCollector = LocationDataCollector()

    // Batcher
    private let batcher: Batcher<T>

    // Builder closure to create T from sensor data
    private let builder: @MainActor (CMMotionActivity, CLLocation) async -> T
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
        builder: @escaping @MainActor (CMMotionActivity, CLLocation) async -> T
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

    private func updateSensorData(activity: CMMotionActivity, location: CLLocation) async {
        let sensorData = await builder(activity, location)
        await batcher.append(sensorData)
        self.sensorData = sensorData
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
    func flush() {
        Task {
            await batcher.flush()
        }
    }
}
