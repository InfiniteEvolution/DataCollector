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

    init() async throws {
        collector = SensorDataCollector()
    }

    @Test func lifecycle() async throws {
        collector.start()
        try await Task.sleep(nanoseconds: 100_000_000)
        collector.flush()
    }
}
