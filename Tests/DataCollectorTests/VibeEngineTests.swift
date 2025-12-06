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
    init() {
        // Force UTC for deterministic testing
    }

    // Helper to create a date on a known Weekday (Monday, Jan 2, 2023)
    // or Weekend (Sunday, Jan 1, 2023).
    // Note: Use UTC Calendar to align with VibeSystem's test-mode override
    func makeDate(isWeekend: Bool, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var components = DateComponents()
        components.year = 2023
        components.month = 1
        components.day = isWeekend ? 1 : 2
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components)!
    }
    
    @Test func exerciseInMorning() {
        // 6:30 AM, Running -> Energetic
        let date = makeDate(isWeekend: false, hour: 6, minute: 30)
        // Speed of running approx 3 m/s
        let result = VibeSystem.evaluate(
            motion: .running, confidence: .high, speed: 3.0, distance: 100, duration: 300,
            timestamp: date)
        #expect(result.vibe == .energetic)
    }

    @Test func workFocusWeekday() {
        // 11:00 AM, Weekday, Stationary -> Focus
        let date = makeDate(isWeekend: false, hour: 11, minute: 0)
        let result = VibeSystem.evaluate(
            motion: .stationary, confidence: .high, speed: 0, distance: 0, duration: 300,
            timestamp: date)
        #expect(result.vibe == .focus)
    }

    @Test func weekendChill() {
        // 11:00 AM, Weekend, Stationary -> Chill
        let date = makeDate(isWeekend: true, hour: 11, minute: 0)
        let result = VibeSystem.evaluate(
            motion: .stationary, confidence: .high, speed: 0, distance: 0, duration: 300,
            timestamp: date)
        #expect(result.vibe == .chill)
    }

    @Test func commute() {
        // 9:30 AM, Weekday, Automotive -> Commute
        let date = makeDate(isWeekend: false, hour: 9, minute: 30)
        // Speed of car > 6 m/s
        let result = VibeSystem.evaluate(
            motion: .automotive, confidence: .high, speed: 10.0, distance: 1000, duration: 300,
            timestamp: date)
        #expect(result.vibe == .commute)
    }

    @Test func eveningCommmute() {
        // 18:00 (6 PM), Weekday, Automotive -> Commute
        let date = makeDate(isWeekend: false, hour: 18, minute: 0)
        let result = VibeSystem.evaluate(
            motion: .automotive, confidence: .high, speed: 8.0, distance: 800, duration: 300,
            timestamp: date)
        #expect(result.vibe == .commute)
    }

    @Test func globalFallbackActive() {
        // 2 PM on Sunday (Weekend), Walking (Active)
        let date = makeDate(isWeekend: true, hour: 14, minute: 0)
        // Walking speed ~ 1.4 m/s
        let result = VibeSystem.evaluate(
            motion: .walking, confidence: .high, speed: 1.4, distance: 100, duration: 300,
            timestamp: date)
        #expect(result.vibe == .energetic)
    }

    @Test func speedInferenceHighSpeed() {
        // 2 PM, Unknown motion (maybe missing CoreMotion update), but high speed -> Travel -> Commute fallback?
        // Commute fallback requires .travel, which speed > 6 triggers.
        let date = makeDate(isWeekend: false, hour: 14, minute: 0)
        let result = VibeSystem.evaluate(
            motion: .unknown, confidence: .high, speed: 20.0, distance: 2000, duration: 300,
            timestamp: date)
        // 2 PM is not commute time (9-10:30, 15:30-19:00).
        // Fallback for .travel is Commute ranked 10.
        // Fallback for Active is Energetic ranked 5.
        // Travel > Active? VibeEngine logic:
        // if speed > 6 -> .travel.
        // Rules:
        // Commute (weekday, travel) 9-10:30 or 15:30-19:00. This is 14:00 (2 PM).
        // Global Fallback Commute (.travel) 0-24 ranked 10.
        // So expected is .commute.
        #expect(result.vibe == .commute)
    }

    @Test func speedInferenceRunning() {
        // 5:30 AM, Unknown motion, speed 3.0 -> High Intensity -> Energetic
        let date = makeDate(isWeekend: false, hour: 5, minute: 30)
        let result = VibeSystem.evaluate(
            motion: .unknown, confidence: .high, speed: 3.0, distance: 100, duration: 300,
            timestamp: date)
        // 5:00-8:00 Active/HighIntensity -> Energetic
        #expect(result.vibe == .energetic)
    }
}
