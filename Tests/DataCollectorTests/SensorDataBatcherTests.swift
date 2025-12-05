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
    var csvStore: CSVStore
    var testPath: String

    init() async throws {
        testPath = "VibeTests/Batcher_" + UUID().uuidString
        fileSystem = FileSystem(.custom(testPath))
        csvStore = CSVStore(fileSystem: fileSystem)
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
        let data = SensorData(motionActivity: .unknown)

        // Act: Add data to buffer
        await batcher.append(data)

        // Assert: Before flush, store may not have written yet
        var datasets = await csvStore.listDatasets()
        // Buffer not yet flushed, so might be empty

        // Act: Force flush
        await batcher.flush()

        // Assert: After flush, exactly one dataset should exist
        datasets = await csvStore.listDatasets()
        #expect(datasets.count == 1)
    }
}
