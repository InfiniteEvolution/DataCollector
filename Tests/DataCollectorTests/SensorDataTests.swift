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

    @Test func defaultInitialization() {
        let data = SensorData()
        #expect(data.activity == .unknown)
        #expect(data.vibe == .unknown)
        #expect(data.probability == 0.0)
        #expect(data.distance == 0.0)
    }

    @Test func csvHeaderCorrectness() {
        let header = SensorData.csvHeader
        #expect(
            header
                == "timestamp,distance,activity,startTime,duration,hour,dayOfWeek,vibe,probability")
    }

    @Test func csvRowFormatting() {
        var data = SensorData()
        // Manually set some values if possible, or rely on default.
        // Since properties are let, we rely on default init for now which gives consistent 0 values.

        var output = ""
        data.writeCSV(to: &output)

        let components = output.split(separator: ",")
        #expect(components.count == 9)

        // Verify specific values we know from default init
        // activity.id for .unknown is 5
        #expect(components[2] == "5")
        // vibe.id for .unknown is 7
        #expect(components[7] == "7")
        // probability is 0.0
        #expect(components[8] == "0.0")
    }

    @Test func activityTypeMapping() {
        #expect(CMActivityType.stationary.id == 0)
        #expect(CMActivityType.walking.id == 1)
        #expect(CMActivityType.running.id == 2)
        #expect(CMActivityType.automotive.id == 3)
        #expect(CMActivityType.cycling.id == 4)
        #expect(CMActivityType.unknown.id == 5)

        #expect(CMActivityType.walking.isMoving)
        #expect(CMActivityType.running.isHighIntensity)
        #expect(!CMActivityType.stationary.isMoving)
    }

    @Test func vibeEnumMapping() {
        #expect(Vibe.sleep.id == 0)
        #expect(Vibe.morningRoutine.id == 1)
        #expect(Vibe.focus.id == 4)
        #expect(Vibe.unknown.id == 7)

        #expect(Vibe.focus.title == "Focus")
    }
}
