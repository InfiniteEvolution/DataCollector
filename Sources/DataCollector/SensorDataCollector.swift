//
//  SensorDataCollector.swift
//  DataCollector
//
//  Created by Antigravity on 30/11/25.
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

    /// The most recent sensor data snapshot.
    public private(set) var sensorData: SensorData

    // Sub-collectors
    private let motionCollector = MotionDataCollector()
    private let locationCollector = LocationDataCollector()

    // Dependencies
    public let store: Store<SensorData>
    public let trainer: OnDeviceTrainer

    // Batcher
    private let batcher: SensorDataBatcher

    // State
    private var previousLocation: CLLocation?
    private var tasks: [Task<Void, Never>] = []

    // MARK: - Initialization

    /// Initializes a new collector and starts observing sub-collectors.
    ///
    /// This initializer acts as the composition root for the Data/Training subsystem.
    /// - Parameter store: Optional store for testing injection. If nil, default dependencies are created.
    public init(store: Store<SensorData>? = nil) {
        // 1. Composition Root: Initialize Dependencies
        let fs = FileSystem(.custom("CanvasData"))
        let csv = CSVStore(fileSystem: fs)
        let models = ModelStore(name: "VibeClassifier", fileSystem: fs)

        // Use injected store or create default
        let actualStore = store ?? Store<SensorData>(csvStore: csv)
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
                let recent = previousLocation ?? location
                let locStruct = SensorData.Location(current: location, recent: recent)

                // When location updates, we use the latest known motion data
                if let lastActivity = motionCollector.currentActivity {
                    updateSensorData(activity: lastActivity, location: locStruct)
                }

                self.previousLocation = location
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
    }

    @MainActor deinit {
        stop()
    }

    private func updateSensorData(activity: CMMotionActivity, location: SensorData.Location? = nil)
    {
        // Resolve Location: Use provided, or construct from current/previous state
        let locStruct: SensorData.Location
        if let location {
            locStruct = location
        } else {
            let current = locationCollector.lastLocation
            let recent = previousLocation ?? current
            locStruct = SensorData.Location(current: current, recent: recent)
        }

        // Dual prediction strategy:
        // 1. VibeEngine prediction for CSV/training data (synchronous)
        let csvData = SensorData(
            motionActivity: activity,
            location: locStruct
        )

        // Send to batcher for CSV writing (uses VibeEngine prediction)
        Task {
            await batcher.append(csvData)
        }

        // 2. ML prediction for UI display (asynchronous, 100% accuracy)
        Task {
            let uiData = await SensorData.withMLPrediction(
                motionActivity: activity,
                location: locStruct
            )
            // Update UI with ML prediction
            self.sensorData = uiData
        }
    }

    private func commit(_ data: SensorData) {
        // Deprecated: No longer used
        // Kept for backward compatibility
        self.sensorData = data
    }

    // MARK: - Public API

    /// Requests authorization for all underlying sensors and starts collection.
    ///
    /// This should be called when the UI appears to ensure the app has necessary permissions
    /// and data flow begins.
    private func requestAuthorization() {
        motionCollector.requestAuthorization()
        locationCollector.requestAuthorization()
    }

    /// Alias for `requestAuthorization` to align with common naming conventions.
    public func start() {
        requestAuthorization()
        motionCollector.start()
        locationCollector.start()
    }

    /// Stops data collection.
    public func stop() {
        motionCollector.stop()
        locationCollector.stop()
        tasks.forEach { $0.cancel() }
        tasks.removeAll()
    }

    /// Forces a flush of the data buffer to disk.
    ///
    /// Call this when the app is about to enter the background to ensure no data is lost.
    public func flush() {
        Task {
            await batcher.flush()
        }
    }

}
