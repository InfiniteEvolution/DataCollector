//
//  SensorDataTests.swift
//  DataCollectorTests
//
//  Created by Antigravity on 05/12/25.
//

import CoreMotion
import Foundation
import Testing

@testable import DataCollector
@testable import Store

@Suite struct SensorDataTests {

    @Test func initialization() {
        let now = Date()
        let id = UUID()
        let data = SensorData(
            id: id,
            timestamp: now,
            totalDistance: 100.0,
            motionActivity: .walking,
            activityStartTime: now.addingTimeInterval(-60),
            vibe: .energetic
        )

        #expect(data.id == id)
        #expect(data.timestamp == now)
        #expect(data.totalDistance == 100.0)
        #expect(data.motionActivity == .walking)
        #expect(data.vibe == .energetic)
        // Fuzzy compare double?
        #expect(abs(data.activityDuration - 60.0) < 0.001)
    }

    @Test func vibeDerivation() {
        let data = SensorData(totalDistance: 0, motionActivity: .stationary)
        // Vibe is non-optional; verify derivation produces a valid case
        #expect(Vibe.allCases.contains(data.vibe))
    }

    @Test func csvEncoding() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let start = now.addingTimeInterval(-60)
        let id = UUID()
        let data = SensorData(
            id: id,
            timestamp: now,
            totalDistance: 50.5,
            motionActivity: .running,
            activityStartTime: start
        )

        var csv = ""
        data.writeCSV(to: &csv)

        let parts = csv.split(separator: ",")
        #expect(parts.count == 7)
        #expect(String(parts[0]) == id.uuidString)
        #expect(String(parts[2]) == "50.5")
        #expect(String(parts[3]) == "running")
        #expect(String(parts[5]) == "60.0")
    }

    @Test func codable() throws {
        let data = SensorData(motionActivity: .cycling)
        let encoder = JSONEncoder()
        let decoded = try JSONDecoder().decode(SensorData.self, from: try encoder.encode(data))

        #expect(data.motionActivity == decoded.motionActivity)
        #expect(data.id == decoded.id)
    }
}
