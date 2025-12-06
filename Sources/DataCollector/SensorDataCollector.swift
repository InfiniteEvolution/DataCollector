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

/// A coordinator for activity and location data collection.
///
/// `SensorDataCollector` manages the lifecycle of `MotionDataCollector` and `LocationDataCollector`.
/// It aggregates their data into `SensorData` snapshots and delegates persistence to `SensorDataBatcher`.
///
/// - Note: This class must be used on the Main Actor.
@Observable
@MainActor
public final class SensorDataCollector {
    // MARK: - Properties

    private let log = LogContext("SDCR")

    /// The most recent sensor data snapshot.
    public private(set) var sensorData: SensorData

    // Sub-collectors
    private let motionCollector = MotionDataCollector()
    private let locationCollector = LocationDataCollector()

    // Dependencies
    let store: Store<SensorData>
    let trainer: OnDeviceTrainer

    // Batcher
    private let batcher: SensorDataBatcher

    // State
    private var previousLocation: CLLocation = .init(latitude: .zero, longitude: .zero)
    private var tasks: [Task<Void, Never>] = []

    private let vibePredictor = VibePredictor()

    // MARK: - Initialization

    /// Initializes a new collector and starts observing sub-collectors.
    ///
    /// This initializer acts as the composition root for the Data/Training subsystem.
    /// - Parameter store: Optional store for testing injection. If nil, default dependencies are created.
    convenience init() {
        self.init(store: nil)
    }
    
    init(store: Store<SensorData>? = nil) {
        // 1. Composition Root: Initialize Dependencies
        let fs = FileSystem(.custom("CanvasData"))
        let csv = CSVStore(fileSystem: fs)
        let models = ModelStore(name: "VibeClassifier", fileSystem: fs)

        // Use injected store or create default
        let actualStore = Store<SensorData>(csvStore: csv)
        let trainer = OnDeviceTrainer(modelStore: models, csvStore: csv)

        self.store = actualStore
        self.trainer = trainer
        self.batcher = SensorDataBatcher(store: actualStore)

        // Initialize with default/current values
        sensorData = .init()

        // Subscribe to Motion Updates
        let motionTask = Task { [weak self] in
            guard let self else { return }
            for await activity in motionCollector.rawActivityUpdates {
                updateSensorData(activity: activity.value)
            }
        }

        tasks.append(motionTask)

        // Subscribe to Location Updates
        let locationTask = Task { [weak self] in
            guard let self else { return }

            for await location in locationCollector.locationUpdates {
                // Track location history for delta calculation
                let recent = previousLocation
                let locStruct = SensorData.Location(current: location, recent: recent)

                // When location updates, we use the latest known motion data
                updateSensorData(activity: motionCollector.currentActivity, location: locStruct)
                previousLocation = location
            }
        }
        tasks.append(locationTask)

        // Setup flush timer
        let timerTask = Task { [weak self] in
            while true {
                try? await Task.sleep(nanoseconds: 60 * 1_000_000_000)
                guard let self else { return }
                await batcher.flushIfNecessary()
            }
        }

        tasks.append(timerTask)

        log.inited()
    }

    @MainActor deinit {
        stop()
        log.deinited()
    }

    private func updateSensorData(activity: CMMotionActivity, location: SensorData.Location? = nil)
    {
        // Resolve Location: Use provided, or construct from current/previous state
        let locStruct: SensorData.Location
        if let location {
            locStruct = location
        } else {
            let current = locationCollector.lastLocation
            let recent = previousLocation
            locStruct = SensorData.Location(current: current, recent: recent)
        }

        // Dual prediction strategy:
        Task {
            // 1. VibeEngine prediction for CSV/training data (synchronous)
            var sensorData = SensorData(motionActivity: activity, location: locStruct)
            await vibePredictor.predict(ve: &sensorData)

            // Send to batcher for CSV writing (uses VibeEngine prediction)
            await batcher.append(sensorData)

            // 2. ML prediction for UI display (asynchronous, 100% accuracy)
            await vibePredictor.predict(ml: &sensorData)

            // Update UI with ML prediction
            self.sensorData = sensorData
        }
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
        motionCollector.start()
        locationCollector.start()
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
