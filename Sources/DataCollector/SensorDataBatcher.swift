//
//  SensorDataBatcher.swift
//  DataCollector
//
//  Created by Sijo on 04/12/25.
//

import Foundation
import Logger
import Store

/// Handles buffering and saving of sensor data to ensure efficient disk I/O.
///
/// `SensorDataBatcher` accumulates `SensorData` points in memory and writes them to the `Store`
/// in batches. This reduces the frequency of disk writes, thereby conserving battery life and reducing
/// system overhead.
///
/// - Note: This actor is thread-safe and designed to be used by `SensorDataCollector`.
actor SensorDataBatcher {
    private let store: Store<SensorData>
    private let log = LogContext("SBAT")

    /// The internal buffer for sensor data.
    private var buffer: [SensorData] = []
    /// The maximum number of items to hold in the buffer before triggering a save.
    private let batchSizeLimit: Int
    /// The maximum time interval to hold data in the buffer before triggering a save.
    private let batchTimeLimit: TimeInterval
    /// The timestamp of the last successful save operation.
    private var lastSaveTime = Date()

    /// Initializes a new batcher with configurable limits.
    ///
    /// - Parameters:
    ///   - store: The store to save data to.
    ///   - batchSize: The number of items to buffer before saving. Default is 500.
    ///   - batchInterval: The time interval (in seconds) to buffer before saving. Default is 300 (5 minutes).
    init(store: Store<SensorData>, batchSize: Int = 500, batchInterval: TimeInterval = 300) {
        self.store = store
        batchSizeLimit = batchSize
        batchTimeLimit = batchInterval
    }

    /// Adds a new data point to the buffer.
    ///
    /// If the buffer size exceeds `batchSizeLimit`, a save operation is triggered immediately.
    ///
    /// - Parameter data: The `SensorData` to add.
    /// Appends a new data point to the buffer.
    ///
    /// If the buffer size exceeds the configured limit, the data is immediately persisted to disk.
    ///
    /// - Parameter data: The `SensorData` snapshot to append.
    func append(_ data: SensorData) async {
        buffer.append(data)

        if buffer.count >= batchSizeLimit {
            await persistBufferedData()
        }
    }

    /// Checks if the buffer should be flushed based on the time elapsed since the last save.
    ///
    /// This method is intended to be called periodically to ensure data is not held in memory
    /// for too long without being written to disk.
    func flushIfNecessary() async {
        let timeSinceLastSave = Date().timeIntervalSince(lastSaveTime)
        if !buffer.isEmpty && timeSinceLastSave >= batchTimeLimit {
            await persistBufferedData()
        }
    }

    /// Forces the buffer to be saved to disk immediately.
    ///
    /// Call this method when the application is transitioning to the background or terminating
    /// to ensure no data is lost.
    func flush() async {
        await persistBufferedData()
    }

    /// Internal method to persist the current buffer to the store.
    ///
    /// This method handles the actual interaction with the `Store` and manages the
    /// buffer state (clearing it after a successful hand-off).
    private func persistBufferedData() async {
        guard !buffer.isEmpty else { return }

        // Capture the buffer and clear it immediately to be ready for new data
        let dataToSave = buffer
        buffer.removeAll(keepingCapacity: true)
        lastSaveTime = Date()

        do {
            // Await the save operation to ensure data is written before proceeding.
            // This provides a clear, linear flow of execution.
            try await store.save(dataToSave)
            log.debug("Successfully saved batch of \(dataToSave.count) items.")
        } catch {
            log.error("Failed to save sensor data batch: \(error)")
        }
    }
}
