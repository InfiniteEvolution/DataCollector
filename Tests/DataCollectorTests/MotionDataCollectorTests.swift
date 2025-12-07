//
//  MotionDataCollectorTests.swift
//  DataCollectorTests
//
//  Created by Sijo on 05/12/25.
//

import Testing

@testable import DataCollector

@Suite @MainActor struct MotionDataCollectorTests {

    @Test func initialization() {
        let collector = MotionDataCollector()
        #expect(collector.currentActivity == nil)
    }

    @Test func startStop() {
        let collector = MotionDataCollector()
        collector.start()
        collector.stop()
    }
}
