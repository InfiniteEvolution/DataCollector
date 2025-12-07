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
    private let log = LogContext("SBAT")
    private let csvStore: CSVStore
    
    /// The internal buffer for sensor data.
    private var buffer: ContiguousArray<SensorData> = []
    /// The maximum number of items to hold in the buffer before triggering a save.
    private let batchSizeLimit = 25
    /// The maximum time interval to hold data in the buffer before triggering a save.
    /// The maximum time interval to hold data in the buffer before triggering a save.
    private let batchTimeLimit = 100.0

    /// The timestamp of the last successful save operation.
    private var lastSaveTime = Date()

    /// Initializes a new batcher with configurable limits.
    ///
    /// - Parameters:
    ///   - store: The store to save data to.
    ///   - batchSize: The number of items to buffer before saving. Default is 500.
    ///   - batchInterval: The time interval (in seconds) to buffer before saving. Default is 300 (5 minutes).
    // Use a background queue for I/O to avoid blocking the main actor
    private let writeQueue = DispatchQueue(label: "com.dataCollector.batchWrite", qos: .utility)

    init(csvStore: CSVStore, batchSize: Int = 25, batchInterval: TimeInterval = 100) {
        self.csvStore = csvStore
        buffer.reserveCapacity(batchSize)  // Optimization: Pre-allocate capacity
        log.inited()
    }

    /// Adds a new data point to the buffer.
    ///
    /// If the buffer size exceeds `batchSizeLimit`, a save operation is triggered immediately.
    ///
    /// - Parameter data: The `SensorData` to add.
    func append(_ data: SensorData) async {
        buffer.append(data)

        guard buffer.count >= batchSizeLimit else {
            log.warning("batchSizeLimit not reached, \(buffer.count) | \(batchSizeLimit).")
            return
        }

        // Offload persistence to background queue
        writeQueue.async {
            Task { await self.persistBufferedData() }
        }
    }

    /// Checks if the buffer should be flushed based on the time elapsed since the last save.
    ///
    /// This method is intended to be called periodically to ensure data is not held in memory
    /// for too long without being written to disk.
    func flushIfNecessary() async {
        let timeSinceLastSave = Date().timeIntervalSince(lastSaveTime)

        guard !buffer.isEmpty else {
            log.warning("Buffer is empty, no need to flush.")
            return
        }

        guard timeSinceLastSave >= batchTimeLimit else {
            log.warning("Flush not needed, time not exceeded. \(buffer.count) | \(batchSizeLimit).")
            return
        }

        await persistBufferedData()
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
        guard !buffer.isEmpty else {
            log.warning("No data to save, buffer is empty.")
            return
        }

        // Capture the buffer and clear it immediately to be ready for new data
        let dataToSave = Array(buffer)
        buffer.removeAll(keepingCapacity: true)
        lastSaveTime = Date()

        // Perform the save operation on the background queue to avoid blocking
        do {
            try await csvStore.save(dataToSave)
            log.info("Successfully saved batch of \(dataToSave.count) items.")
        } catch {
            log.warning("Failed to save sensor data batch: \(error.localizedDescription)")
        }
    }

    deinit {
        log.deinited()
    }
}
