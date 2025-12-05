//
//  VibeEngine.swift
//  DataCollector
//
//  Created by Antigravity on 05/12/25.
//

import CoreLocation
import CoreMotion
import Foundation

// MARK: - Vibe Engine Types

enum ActivityLevel: Hashable {
    case stationary
    case active
    case highIntensity
    case travel
}

enum DayType {
    case weekday
    case weekend
}

struct TimePoint: Comparable, CustomStringConvertible {
    let hour: Int
    let minute: Int

    static func < (lhs: TimePoint, rhs: TimePoint) -> Bool {
        if lhs.hour != rhs.hour { return lhs.hour < rhs.hour }
        return lhs.minute < rhs.minute
    }

    var description: String {
        String(format: "%02d:%02d", hour, minute)
    }

    static func current(from date: Date, using calendar: Calendar = .current) -> TimePoint {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        return TimePoint(hour: hour, minute: minute)
    }
}

struct Context {
    let time: TimePoint
    let day: DayType
    let activity: ActivityLevel
}

struct Rule {
    let vibe: Vibe
    var timeRanges: [Range<TimePoint>] = []
    var days: Set<DayType> = [.weekday, .weekend]
    var activities: Set<ActivityLevel> = []
    var priority: Int = 0

    // Specificity Score: Duration of the time window (smaller is more specific)
    var specificity: Int {
        guard let range = timeRanges.first else { return Int.max }
        let startMinutes = range.lowerBound.hour * 60 + range.lowerBound.minute
        let endMinutes = range.upperBound.hour * 60 + range.upperBound.minute
        // Handle overnight wrap-around for calculation if needed
        let adjustedEnd = endMinutes < startMinutes ? endMinutes + (24 * 60) : endMinutes
        return adjustedEnd - startMinutes
    }

    // Fluent Builder API

    func between(_ startHour: Int, _ startMinute: Int) -> RangeBuilder {
        RangeBuilder(rule: self, start: TimePoint(hour: startHour, minute: startMinute))
    }

    struct RangeBuilder {
        let rule: Rule
        let start: TimePoint

        func and(_ endHour: Int, _ endMinute: Int) -> Rule {
            var copy = rule
            let end = TimePoint(hour: endHour, minute: endMinute)

            if start > end {
                // Overnight range: Split into start..<24:00 and 00:00..<end
                copy.timeRanges.append(start..<TimePoint(hour: 24, minute: 0))
                copy.timeRanges.append(TimePoint(hour: 0, minute: 0)..<end)
            } else {
                copy.timeRanges.append(start..<end)
            }
            return copy
        }
    }

    func on(_ days: DayType...) -> Rule {
        var copy = self
        copy.days = Set(days)
        return copy
    }

    func when(_ activities: ActivityLevel...) -> Rule {
        var copy = self
        copy.activities = Set(activities)
        return copy
    }

    func ranked(_ priority: Int) -> Rule {
        var copy = self
        copy.priority = priority
        return copy
    }

    // Evaluation

    func matches(_ context: Context) -> Bool {
        guard days.contains(context.day) else { return false }
        guard activities.contains(context.activity) else { return false }

        return timeRanges.contains { range in
            range.contains(context.time)
        }
    }
}

// MARK: - Result Builder

@resultBuilder
struct VibeEngineBuilder {
    static func buildBlock(_ components: [Rule]...) -> [Rule] {
        components.flatMap { $0 }
    }

    static func buildExpression(_ expression: Rule) -> [Rule] {
        [expression]
    }

    static func buildExpression(_ expression: [Rule]) -> [Rule] {
        expression
    }

    // Support for if statements
    static func buildOptional(_ component: [Rule]?) -> [Rule] {
        component ?? []
    }

    // Support for if-else statements
    static func buildEither(first component: [Rule]) -> [Rule] {
        component
    }

    static func buildEither(second component: [Rule]) -> [Rule] {
        component
    }
}

// Helper to define the engine block
func VibeEngine(@VibeEngineBuilder _ content: () -> [Rule]) -> [Rule] {
    content()
}

// MARK: - Vibe System

struct VibeSystem {
    private static let calendar = Calendar.current

    // Pre-computed ruleset to avoid allocation on every evaluation
    // We use explicit .on() modifiers instead of dynamic if/else checks
    private static let rules: [Rule] = VibeEngine {
        // --- Always Active Rules ---

        // Sleep: 9:00 PM - 5:00 AM
        rule(for: .sleep)
            .when(.stationary)
            .between(21, 00).and(5, 00)
            .ranked(100)

        // Morning Routine: 5:00 AM - 7:00 AM
        rule(for: .morningRoutine)
            .when(.stationary)
            .between(5, 00).and(7, 00)
            .ranked(90)

        // Exercise
        rule(for: .energetic)
            .when(.active, .highIntensity)
            .between(5, 00).and(8, 00)
            .ranked(85)

        rule(for: .energetic)
            .when(.active, .highIntensity)
            .between(17, 00).and(18, 45)
            .ranked(85)

        // Meals
        rule(for: .meal)
            .when(.stationary)
            .between(7, 00).and(10, 00)
            .ranked(80)

        rule(for: .meal)
            .when(.stationary)
            .between(12, 00).and(13, 30)
            .ranked(80)

        rule(for: .meal)
            .when(.stationary)
            .between(20, 00).and(21, 00)
            .ranked(80)

        // --- Conditional Rules (Explicit) ---

        // Weekday-only rules
        // Commute
        rule(for: .commute)
            .on(.weekday)
            .when(.active, .travel)
            .between(9, 00).and(10, 30)
            .ranked(75)

        rule(for: .commute)
            .on(.weekday)
            .when(.active, .travel)
            .between(15, 30).and(19, 00)
            .ranked(75)

        // Work Blocks
        rule(for: .focus)
            .on(.weekday)
            .when(.stationary)
            .between(10, 00).and(13, 00)
            .ranked(70)

        rule(for: .focus)
            .on(.weekday)
            .when(.stationary)
            .between(13, 00).and(15, 30)
            .ranked(70)

        rule(for: .focus)
            .on(.weekday)
            .when(.stationary)
            .between(15, 30).and(19, 00)
            .ranked(70)

        // Weekend-only rules
        // Weekend Chill: 7:00 AM - 9:00 PM
        rule(for: .chill)
            .on(.weekend)
            .when(.stationary)
            .between(7, 00).and(21, 00)
            .ranked(50)

        // --- Fallbacks ---

        // Evening Chill (Every day)
        rule(for: .chill)
            .when(.stationary)
            .between(18, 40).and(20, 00)
            .ranked(60)

        // Global Fallbacks
        rule(for: .energetic)
            .when(.highIntensity)
            .between(0, 00).and(24, 00)
            .ranked(10)

        rule(for: .commute)
            .when(.travel)
            .between(0, 00).and(24, 00)
            .ranked(10)

        rule(for: .energetic)
            .when(.active)
            .between(0, 00).and(24, 00)
            .ranked(5)

        rule(for: .chill)
            .when(.stationary)
            .between(0, 00).and(24, 00)
            .ranked(1)
    }

    static func evaluate(motion: CMActivityType, distance: Double, timestamp: Date) -> Vibe {
        // 1. Build Context
        let time = TimePoint.current(from: timestamp, using: Self.calendar)

        let isWeekend = Self.calendar.isDateInWeekend(timestamp)
        let dayType: DayType = isWeekend ? .weekend : .weekday

        let activityLevel: ActivityLevel
        if motion == .running || motion == .cycling {
            activityLevel = .highIntensity
        } else if motion == .automotive {
            activityLevel = .travel
        } else if motion == .walking {
            activityLevel = .active
        } else {
            activityLevel = .stationary
        }

        let context = Context(time: time, day: dayType, activity: activityLevel)

        // 3. Evaluate with Specificity Tie-Breaking
        // Iterating static array is allocation-free
        let bestMatch =
            Self.rules
            .filter { $0.matches(context) }
            .max { a, b in
                if a.priority != b.priority {
                    return a.priority < b.priority
                }
                return a.specificity > b.specificity
            }

        return bestMatch?.vibe ?? .unknown
    }
}

func rule(for vibe: Vibe) -> Rule {
    Rule(vibe: vibe)
}
