//
//  SensorDataCollectorTests.swift
//  DataCollectorTests
//
//  Created by Sijo on 05/12/25.
//

import Foundation
import Testing

@testable import DataCollector
@testable import Store

@Suite @MainActor final class SensorDataCollectorTests {
    var collector: SensorDataCollector
    var store: Store<SensorData>
    var fileSystem: FileSystem
    var testPath: String

    init() async throws {
        testPath = "VibeTests/Collector_" + UUID().uuidString
        fileSystem = FileSystem(.custom(testPath))
        let csvStore = CSVStore(fileSystem: fileSystem)
        store = Store(csvStore: csvStore)

        collector = SensorDataCollector(store: store)
    }

    deinit {
        try? FileManager.default.removeItem(
            at: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(testPath, isDirectory: true)
        )
    }

    @Test func lifecycle() async throws {
        collector.start()
        try await Task.sleep(nanoseconds: 100_000_000)
        collector.stop()
    }
    @Test func initialState() async throws {
        // Verify default state before collection
        let data = collector.sensorData
        
        #expect(data.vibe == .unknown)
        #expect(data.activity == .unknown)
        #expect(data.probability == 0.0)
    }
}
