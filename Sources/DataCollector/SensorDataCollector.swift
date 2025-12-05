//
//  SensorDataCollector.swift
//  DataCollector
//
//  Created by Sijo on 30/11/25.
//

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

    private let log = LogContext("SDAT")

    // Sub-collectors
    private let motionCollector = MotionDataCollector()
    private let locationCollector = LocationDataCollector()

    // Dependencies
    public let store: Store<SensorData>
    public let trainer: OnDeviceTrainer
    private let fileSystem: FileSystem
    private let csvStore: CSVStore
    private let modelStore: ModelStore

    // Batcher
    private let batcher: SensorDataBatcher

    // Lifecycle Management
    private var tasks: [Task<Void, Never>] = []

    // MARK: - Initialization

    /// Initializes a new collector and starts observing sub-collectors.
    ///
    /// This initializer acts as the composition root for the Data/Training subsystem.
    public init() {
        // 1. Composition Root: Initialize Dependencies
        let fs = FileSystem(.custom("CanvasData"))
        let csv = CSVStore(fileSystem: fs)
        let models = ModelStore(name: "VibeClassifier", fileSystem: fs)
        let store = Store<SensorData>(csvStore: csv)
        let trainer = OnDeviceTrainer(modelStore: models, csvStore: csv)

        self.fileSystem = fs
        self.csvStore = csv
        self.modelStore = models
        self.store = store
        self.trainer = trainer
        self.batcher = SensorDataBatcher(store: store)

        // Initialize with default/current values
        sensorData = .init()

        // Subscribe to Motion Updates
        let motionTask = Task { [weak self] in
            guard let self else { return }
            for await activityType in motionCollector.activityUpdates {
                updateSensorData(
                    motionActivity: activityType,
                    activityStartTime: motionCollector.activityStartTime
                )
            }
        }
        tasks.append(motionTask)

        // Subscribe to Location Updates
        let locationTask = Task { [weak self] in
            guard let self else { return }
            for await _ in locationCollector.locationUpdates {
                // When location updates, we use the latest known motion data
                updateSensorData(
                    motionActivity: motionCollector.activityType,
                    activityStartTime: motionCollector.activityStartTime
                )
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
        tasks.forEach { $0.cancel() }
    }

    private func updateSensorData(motionActivity: CMActivityType, activityStartTime: Date) {
        let now = Date()
        let currentDistance = locationCollector.totalDistance

        sensorData = SensorData(
            timestamp: now,
            totalDistance: currentDistance,
            motionActivity: motionActivity,
            activityStartTime: activityStartTime
        )

        Task {
            await batcher.append(sensorData)
        }
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
