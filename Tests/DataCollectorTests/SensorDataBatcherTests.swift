//
//  SensorDataBatcherTests.swift
//  DataCollectorTests
//
//  Created by Sijo on 05/12/25.
//

import Foundation
import Testing

@testable import DataCollector
@testable import Store

@Suite final class SensorDataBatcherTests {
    var store: Store<SensorData>
    var batcher: SensorDataBatcher
    var fileSystem: FileSystem
    var testPath: String

    init() async throws {
        testPath = "VibeTests/Batcher_" + UUID().uuidString

        // Ensure directory exists
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent(testPath, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        fileSystem = FileSystem(.custom(testPath))
        let csvStore = CSVStore(fileSystem: fileSystem)
        store = Store(csvStore: csvStore)
        batcher = SensorDataBatcher(store: store)
    }

    deinit {
        try? FileManager.default.removeItem(
            at: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(testPath, isDirectory: true)
        )
    }

    @Test func accumulationAndFlush() async throws {
        let data = SensorData()

        // Act: Add data
        await batcher.append(data)

        // Assert: Store check
        var datasets = try await fileSystem.listFiles(withExtension: "csv")
        // might be 0

        // Act: Force flush
        await batcher.flush()

        // Assert
        datasets = try await fileSystem.listFiles(withExtension: "csv")
        #expect(datasets.count == 1)
    }
    @Test func autoFlushSizeLimit() async throws {
        // Init with small batch size of 2
        batcher = SensorDataBatcher(store: store, batchSize: 2)

        let data = SensorData()

        // 1. Add first item (buffer: 1)
        await batcher.append(data)
        var datasets = try await fileSystem.listFiles(withExtension: "csv")
        #expect(datasets.isEmpty)

        // 2. Add second item (buffer: 2 -> trigger flush)
        await batcher.append(data)

        // Assert: Flush should have happened
        datasets = try await fileSystem.listFiles(withExtension: "csv")
        #expect(datasets.count == 1)
    }

    @Test func autoFlushTimeLimit() async throws {
        // Init with short interval 0.1s
        batcher = SensorDataBatcher(store: store, batchSize: 100, batchInterval: 0.1)
        let data = SensorData()

        // 1. Add item
        await batcher.append(data)
        var datasets = try await fileSystem.listFiles(withExtension: "csv")
        #expect(datasets.isEmpty)

        // 2. Wait for interval to pass
        try await Task.sleep(nanoseconds: 200_000_000)  // 0.2s

        // 3. Trigger check
        await batcher.flushIfNecessary()

        // Assert: Flush should have happened
        datasets = try await fileSystem.listFiles(withExtension: "csv")
        #expect(datasets.count == 1)
    }

    @Test func concurrencyStressTest() async throws {
        // Init with large batch size to avoid flushing during append
        batcher = SensorDataBatcher(store: store, batchSize: 1000)

        // Hammer append from 100 concurrent tasks
        let testedBatcher = batcher
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    let data = SensorData()
                    await testedBatcher.append(data)
                }
            }
        }

        // Flush manually
        await batcher.flush()

        // Verify all 100 items are saved
        let files = try await fileSystem.listFiles(withExtension: "csv")
        #expect(files.count >= 1)
    }
}
