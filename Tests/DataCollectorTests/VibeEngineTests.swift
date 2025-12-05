//
//  VibeEngineTests.swift
//  DataCollectorTests
//
//  Created by Sijo on 05/12/25.
//

import CoreMotion
import Foundation
import Testing

@testable import DataCollector

@Suite struct VibeEngineTests {

    // Helper to create a date on a known Weekday (Monday, Jan 2, 2023)
    // or Weekend (Sunday, Jan 1, 2023).
    // Note: Use Calendar.current to align with VibeSystem usage
    func makeDate(isWeekend: Bool, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = 2023
        components.month = 1
        components.day = isWeekend ? 1 : 2
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }

    @Test func sleep() {
        // 3:00 AM, Stationary -> Sleep
        let date = makeDate(isWeekend: false, hour: 3, minute: 0)
        let vibe = VibeSystem.evaluate(motion: .stationary, distance: 0, timestamp: date)
        #expect(vibe == .sleep)
    }

    @Test func morningRoutine() {
        // 6:00 AM, Stationary -> Morning Routine
        let date = makeDate(isWeekend: false, hour: 6, minute: 0)
        let vibe = VibeSystem.evaluate(motion: .stationary, distance: 0, timestamp: date)
        #expect(vibe == .morningRoutine)
    }

    @Test func exerciseInMorning() {
        // 6:30 AM, Running -> Energetic (Exercise rule ranked 85 vs Morning Routine 90?)
        // Wait, Morning Routine (Stationary) ranked 90.
        // If Running, Morning Routine (requires Stationary) does NOT match.
        // Exercise rule (Active/HighIntensity) matches. Ranked 85.
        // So expected is Energetic.

        let date = makeDate(isWeekend: false, hour: 6, minute: 30)
        let vibe = VibeSystem.evaluate(motion: .running, distance: 100, timestamp: date)
        #expect(vibe == .energetic)
    }

    @Test func workFocusWeekday() {
        // 11:00 AM, Weekday, Stationary -> Focus
        let date = makeDate(isWeekend: false, hour: 11, minute: 0)
        let vibe = VibeSystem.evaluate(motion: .stationary, distance: 0, timestamp: date)
        #expect(vibe == .focus)
    }

    @Test func weekendChill() {
        // 11:00 AM, Weekend, Stationary -> Chill
        // Focus is weekday only.
        // Weekend Chill (7-21) matches weekend stationary.
        let date = makeDate(isWeekend: true, hour: 11, minute: 0)
        let vibe = VibeSystem.evaluate(motion: .stationary, distance: 0, timestamp: date)
        #expect(vibe == .chill)
    }

    @Test func commute() {
        // 9:30 AM, Weekday, Automotive -> Commute
        let date = makeDate(isWeekend: false, hour: 9, minute: 30)
        let vibe = VibeSystem.evaluate(motion: .automotive, distance: 1000, timestamp: date)
        #expect(vibe == .commute)
    }

    @Test func eveningCommmute() {
        // 18:00 (6 PM), Weekday, Automotive -> Commute
        let date = makeDate(isWeekend: false, hour: 18, minute: 0)
        let vibe = VibeSystem.evaluate(motion: .automotive, distance: 1000, timestamp: date)
        #expect(vibe == .commute)
    }

    @Test func globalFallbackActive() {
        // 2 PM on Sunday (Weekend), Walking (Active)
        // Weekend Chill requires Stationary.
        // No specific active rule for 2 PM except global Energetic (5).
        let date = makeDate(isWeekend: true, hour: 14, minute: 0)
        let vibe = VibeSystem.evaluate(motion: .walking, distance: 100, timestamp: date)
        #expect(vibe == .energetic)
    }
}
