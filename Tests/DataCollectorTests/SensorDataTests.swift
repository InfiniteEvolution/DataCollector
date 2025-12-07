//
//  SensorDataTests.swift
//  DataCollectorTests
//
//  Created by Sijo on 05/12/25.
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
            distance: 100.0,
            activity: .walking,
            startTime: now.addingTimeInterval(-60),
            vibe: .energetic,
            id: id,
            timestamp: now
        )

        #expect(data.id == id)
        #expect(data.timestamp == now)
        #expect(data.distance == 100.0)
        #expect(data.activity == .walking)
        #expect(data.vibe == .energetic)
        // Fuzzy compare double?
        #expect(abs(data.duration - 60.0) < 0.001)
    }

    @Test func vibeDerivation() {
        let data = SensorData(distance: 0, activity: .stationary)
        #expect(data.vibe == .unknown)
    }

    @Test func csvEncoding() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let start = now.addingTimeInterval(-60)
        let id = UUID()
        let data = SensorData(
            distance: 50.5,
            activity: .running,
            startTime: start,
            vibe: .energetic,
            id: id,
            timestamp: now
        )

        var csv = ""
        data.writeCSV(to: &csv)

        let parts = csv.split(separator: ",")
        #expect(parts.count == 9)
        // Timestamp (Double)
        #expect(Double(parts[0]) != nil)
        // Distance (50.5)
        #expect(Double(parts[1]) == 50.5)
        // Activity ID (running = 2)
        #expect(parts[2] == "2")
        // StartTime (Double)
        #expect(Double(parts[3]) != nil)
        // Duration (60.0)
        #expect(Double(parts[4]) == 60.0)
        // Hour (From timestamp)
        #expect(Int(parts[5]) != nil)
        // DayOfWeek
        #expect(Int(parts[6]) != nil)
        // Vibe ID (energetic = 2)
        #expect(parts[7] == "2")
        // Probability
        #expect(Double(parts[8]) != nil)
    }

    @Test func codable() throws {
        let data = SensorData(activity: .cycling)
        let encoder = JSONEncoder()
        let decoded = try JSONDecoder().decode(SensorData.self, from: try encoder.encode(data))

        #expect(data.activity == decoded.activity)
        #expect(data.id == decoded.id)
    }
}
