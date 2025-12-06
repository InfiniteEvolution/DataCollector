//
//  SensorDataBatcherTests.swift
//  DataCollectorTests
//
//  Created by Antigravity on 05/12/25.
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
}
