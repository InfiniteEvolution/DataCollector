//
//  VibeEngine.swift
//  DataCollector
//
//  Created by Sijo on 05/12/25.
//

import CoreLocation
import CoreMotion
import Foundation

// MARK: - Vibe Engine Types

struct ActivityLevel: OptionSet, Hashable {
    let rawValue: Int

    static let stationary = ActivityLevel(rawValue: 1 << 0)
    static let walking = ActivityLevel(rawValue: 1 << 1)
    static let running = ActivityLevel(rawValue: 1 << 2)
    static let cycling = ActivityLevel(rawValue: 1 << 3)
    static let automotive = ActivityLevel(rawValue: 1 << 4)
}

struct Rule {
    let vibe: Vibe
    var timeRanges: [Range<Int>] = []  // Minutes from midnight (0...1440)
    var activities: ActivityLevel = []
    var priority: Int = 0
    var likelihood: Double = 1.0

    // Specificity Score: Duration of the time window (smaller is more specific)
    var specificity: Int {
        // Sum all ranges to handle overnight splits (e.g. 23:00-05:00 is two ranges)
        return timeRanges.reduce(0) { $0 + ($1.upperBound - $1.lowerBound) }
    }

    // Fluent Builder API

    func between(_ startHour: Int, _ startMinute: Int) -> RangeBuilder {
        RangeBuilder(rule: self, startMinutes: startHour * 60 + startMinute)
    }

    struct RangeBuilder {
        let rule: Rule
        let startMinutes: Int

        func and(_ endHour: Int, _ endMinute: Int) -> Rule {
            var copy = rule
            let endMinutes = endHour * 60 + endMinute

            if startMinutes > endMinutes {
                // Overnight range: Split into start..<1440 and 0..<end
                copy.timeRanges.append(startMinutes..<1440)
                copy.timeRanges.append(0..<endMinutes)
            } else {
                copy.timeRanges.append(startMinutes..<endMinutes)
            }
            return copy
        }
    }

    func when(_ activities: ActivityLevel...) -> Rule {
        var copy = self
        // Union of all passed activities
        copy.activities = activities.reduce(into: ActivityLevel()) { $0.insert($1) }
        return copy
    }

    func ranked(_ priority: Int) -> Rule {
        var copy = self
        copy.priority = priority
        return copy
    }

    func likely(_ probability: Double) -> Rule {
        var copy = self
        copy.likelihood = probability
        return copy
    }

    // Evaluation

    // Evaluation
    // (Matches logic is now inlined into VibeSystem.lookupTable initialization)
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

// MARK: - Vibe Engine System

// MARK: - Vibe Engine System

enum VibeSystem {
    // AutoupdatingCurrent ensures we track Timezone changes immediately without restart
    static let timeZone = TimeZone.autoupdatingCurrent

    // Helper builder for DSL
    @inline(__always)
    static func rule(for vibe: Vibe) -> Rule {
        Rule(vibe: vibe)
    }

    // MARK: - Lookup Optimization

    // MARK: - Lookup Optimization

    struct EngineResult {
        let vibe: Vibe
        // Optimization: Compress Probability to UInt8 (0-255 scaled)
        // Reduces struct size from 16 bytes (1+7pad+8) to 2 bytes (1+1).
        // Table size drops from ~256KB to 32KB (Fits in L1 Cache).
        let probByte: UInt8

        static let empty = EngineResult(vibe: .unknown, probByte: 0)

        @inline(__always)
        var probability: Double {
            // Optimization: Multiply by reciprocal (1/255) instead of dividing
            Double(probByte) * 0.003921568627451
        }
    }

    // O(1) Lookup Table with Bitwise Indexing
    // Dimensions: [ActivityLevel(8 slots)][Minute(2048)]
    // Activity uses 5 indices (0-4), requiring 3 bits (8 slots).
    // Total Size: 8 * 2048 = 16,384 items.
    private static let lookupTable: ContiguousArray<EngineResult> = {
        // Define Rules locally to avoid permanent static memory retention
        let rules: [Rule] = VibeEngine {
            // --- RESEARCH-BACKED RULES (ATUS 2024 + Chronotype Studies) ---
            // Full-time work: 8.1h/day (8.4h weekdays, 5.6h weekends)
            // Leisure: 5.5h men, 4.7h women, 7.6h age 75+, 3.8h age 35-44
            // Household: 2h/day, Childcare: 2.5h/day (kids <6)

            // --- High Priority Overrides (90-100) ---

            // Sleep: 11:00 PM - 7:00 AM (Stationary) - Average 7-8h
            // Research: Most adults sleep 7-9h, with variations by age
            rule(for: .sleep)
                .when(.stationary)
                .between(23, 00).and(7, 00)
                .ranked(100)
                .likely(0.95)

            // Intense Exercise (Running/Cycling anytime)
            // Research: Only 28% meet exercise guidelines, but high confidence when detected
            rule(for: .energetic)
                .when(.running, .cycling)
                .between(0, 00).and(24, 00)
                .ranked(95)
                .likely(0.9)

            // Morning Routine: 6 AM - 9 AM (Stationary)
            // Research: Extended to cover various chronotypes (larks wake 5:30-6, owls 8-9)
            rule(for: .morningRoutine)
                .when(.stationary)
                .between(6, 00).and(9, 00)
                .ranked(85)
                .likely(0.9)

            // --- Work & Focus (70-80) ---
            // Research: Full-time workers average 8.1h work, peak productivity varies by age
            // Young adults (25-35): Peak 2-6 PM (night owls)
            // Mid-career (35-45): Peak 9 AM-2 PM (intermediate)
            // Seniors (55+): Peak 8 AM-12 PM (morning larks)

            // Morning Work: 9 AM - 12 PM (Stationary) - Peak for larks/intermediate
            rule(for: .focus)
                .when(.stationary)
                .between(9, 00).and(12, 00)
                .ranked(80)
                .likely(0.85)

            // Afternoon Work: 1 PM - 5 PM - Peak for owls
            rule(for: .focus)
                .when(.stationary)
                .between(13, 00).and(17, 00)
                .ranked(80)
                .likely(0.8)

            // Late Night Work: 8 PM - 12 AM (Stationary) - Night owls peak productivity
            // Research: Young professionals (night owls) often work late
            rule(for: .focus)
                .when(.stationary)
                .between(20, 00).and(0, 00)
                .ranked(75)
                .likely(0.6)

            // --- Commute (70-75) ---
            // Research: Average commute 27.6 min one-way (45-50 min round trip)

            // Morning Commute (Automotive/Walking)
            rule(for: .commute)
                .when(.automotive, .walking)
                .between(8, 00).and(9, 00)
                .ranked(75)
                .likely(0.9)

            // Evening Commute
            rule(for: .commute)
                .when(.automotive, .walking)
                .between(17, 30).and(18, 30)
                .ranked(75)
                .likely(0.9)

            // --- Fitness & Health (60-85) ---
            // Research: Only 28% meet exercise guidelines, but patterns are consistent
            // Morning: 6-8 AM (larks), Lunch: 12-1 PM, Evening: 5-7 PM (most common)

            // Morning Walk/Exercise (Larks)
            rule(for: .energetic)
                .when(.walking)
                .between(6, 00).and(8, 00)
                .ranked(85)
                .likely(0.8)

            // Lunch Walk/Gym
            rule(for: .energetic)
                .when(.walking, .running, .cycling)
                .between(12, 00).and(13, 30)
                .ranked(85)
                .likely(0.7)

            // Evening Workout (Most common time)
            rule(for: .energetic)
                .when(.walking, .running, .cycling)
                .between(17, 00).and(19, 00)
                .ranked(85)
                .likely(0.75)

            // --- Leisure & Social (40-60) ---
            // Research: Leisure 5.5h men, 4.7h women, 7.6h age 75+, 3.8h age 35-44
            // TV watching: 2.6h/day average, Socializing: 35min/day

            // Evening Leisure: 7 PM - 11 PM (Prime time)
            // Research: Most leisure happens in evening hours
            rule(for: .chill)
                .when(.stationary)
                .between(19, 00).and(23, 00)
                .ranked(60)
                .likely(0.8)

            // Weekend Brunch/Social: 10 AM - 2 PM
            rule(for: .chill)
                .when(.stationary, .walking)
                .between(10, 00).and(14, 00)
                .ranked(60)
                .likely(0.7)

            // Late Night Social (Fri/Sat): 10 PM - 2 AM
            rule(for: .chill)
                .when(.walking, .stationary)
                .between(22, 00).and(2, 00)
                .ranked(55)
                .likely(0.5)

            // --- Default Fallbacks (0-10) ---

            // General Walking -> Energetic (Mild)
            rule(for: .energetic)
                .when(.walking)
                .between(0, 00).and(24, 00)
                .ranked(10)

            // General Automotive -> Commute
            rule(for: .commute)
                .when(.automotive)
                .between(0, 00).and(24, 00)
                .ranked(10)

            // General Running/Cycling -> Energetic
            rule(for: .energetic)
                .when(.running, .cycling)
                .between(0, 00).and(24, 00)
                .ranked(10)

            // General Stationary -> Chill
            rule(for: .chill)
                .when(.stationary)
                .between(0, 00).and(24, 00)
                .ranked(5)

        }.sorted {
            // 1. Sort Priority High -> Low
            if $0.priority != $1.priority {
                return $0.priority > $1.priority
            }
            // 2. Sort Likelihood High -> Low
            if $0.likelihood != $1.likelihood {
                return $0.likelihood > $1.likelihood
            }
            // 3. Sort Specificity Low -> High (Smaller duration is better)
            return $0.specificity < $1.specificity
        }

        // Initialize with .empty (Unknown)
        var table = ContiguousArray<EngineResult>(repeating: .empty, count: 16384)

        // Targeted Filling (Optimize Init):
        // Instead of checking every slot against every rule (O(Slots * Rules)),
        // we iterate Rules and fill only the slots they cover.
        // Rules are sorted Priority High -> Low. We fill only if empty (First match wins).

        for rule in rules {
            // Pre-calc Logic Constants for this Rule (Hoisted)
            var baseProb = rule.likelihood
            let duration = Double(rule.specificity)

            // 1. Time Specificity Bonus (Static for the Rule)
            if duration >= 10 && duration <= 60 {
                baseProb *= 1.1
            } else if duration > 720 {
                baseProb *= 0.9
            }

            // Optimization: Remove array allocation for indices.
            // Iterate known activity bits (0..4) directly.
            for actIdx in 0...4 {
                // Construct the OptionSet equivalent for this index
                let bit = 1 << actIdx
                // Only proceed if the Rule covers this activity bit
                if (rule.activities.rawValue & bit) != 0 {

                    for range in rule.timeRanges {
                        // Range is 0..<1440.
                        let lower = range.lowerBound
                        let upper = range.upperBound

                        // Edge Dampening Constants
                        let rangeDur = Double(upper - lower)
                        let buffer = min(rangeDur * 0.1, 15.0)
                        let hasBuffer = buffer > 0
                        let rangeStart = Double(lower)
                        let rangeEnd = Double(upper)

                        for m in lower..<upper {
                            let index = (actIdx << 11) | m
                            // Bitwise Mask for safety, though loop bounds ensure it fits 0..16383 ranges if correct
                            let safeIndex = index & 0x3FFF

                            // ONLY fill if empty (Higher priority rules came first)
                            if table[safeIndex].vibe == .unknown {
                                var prob = baseProb

                                // 2. Edge Dampening (Dynamic per minute)
                                if hasBuffer {
                                    let current = Double(m)
                                    let distStart = current - rangeStart
                                    let distEnd = rangeEnd - current
                                    let minDist = min(distStart, distEnd)

                                    if minDist < buffer {
                                        // Linear ramp from 0.8 to 1.0
                                        let factor = 0.8 + (0.2 * (minDist / buffer))
                                        prob *= factor
                                    }
                                }

                                // Optimization: Compress to UInt8
                                let probByte = UInt8(min(prob * 255.0, 255.0))
                                table[safeIndex] = EngineResult(vibe: rule.vibe, probByte: probByte)
                            }
                        }
                    }
                }
            }
        }
        return table
    }()

    @inline(__always)
    private static func activityIndex(for level: ActivityLevel) -> Int {
        // OptionSet rawValue is 1, 2, 4, 8, 16.
        // trailingZeroBitCount maps:
        // 1 (Stationary) -> 0
        // 2 (Walking)    -> 1
        // 4 (Running)    -> 2
        // 8 (Cycling)    -> 3
        // 16 (Automotive) -> 4
        return level.rawValue.trailingZeroBitCount
    }

    /// Abstract confidence level to decouple from CoreMotion
    enum Confidence: Int {
        case low, medium, high
    }

    @inline(__always)
    static func evaluate(
        motion: CMActivityType,
        confidence: Confidence,
        speed: CLLocationSpeed,
        distance: Double,
        duration: TimeInterval,
        timestamp: Date
    ) -> (vibe: Vibe, probability: Double) {
        // 1. Build Context Inputs
        // Optimization: Replace heavy Calendar/DateComponents with pure Integer Math
        // Calendar calls allocate internal buffers and do complex lookup.
        // TimeZone offset + Modulo is extremely fast and wall-clock correct.

        let seconds = Int(timestamp.timeIntervalSince1970)
        let offset = Self.timeZone.secondsFromGMT(for: timestamp)

        // Calculate minutes from midnight directly
        // (EpochSeconds + GMTOffset) % 86400 / 60
        var totalSeconds = (seconds + offset) % 86400
        if totalSeconds < 0 { totalSeconds += 86400 }  // Safety for historic/negative dates

        let minutesFromMidnight = totalSeconds / 60
        // Extract hour for plausibility check check
        let hour = minutesFromMidnight / 60

        // 2. Classify Activity using Motion, Speed, and Duration
        var activityLevel: ActivityLevel
        var isPhysicsOverride = false  // Track if we forced a classification

        // Physics & Logic Constraints

        // High Speed -> Automotive/Travel
        // 20 m/s (~72 km/h) is definitely automotive
        if speed >= 20.0 {
            activityLevel = .automotive
            isPhysicsOverride = true
        }
        // Human Speed Limits
        // Usain Bolt ~12.4 m/s. Sustained running > 10 m/s is suspicious for non-pros.
        else if motion == .running && speed > 12.0 {
            activityLevel = .automotive
            isPhysicsOverride = true
        }
        // Cycling > 15 m/s (~54 km/h) is pro/downhill, but plausible.
        // If > 25 m/s (~90 km/h), likely motorcycle/car.
        else if motion == .cycling && speed > 25.0 {
            activityLevel = .automotive
            isPhysicsOverride = true
        } else {
            // Standard classification
            switch motion {
            case .automotive:
                activityLevel = .automotive
            case .cycling:
                // Moving very slowly? Maybe walking bike.
                if speed > 0 && speed < 1.0 {  // < 3.6 km/h
                    activityLevel = .walking
                } else {
                    activityLevel = .cycling
                }
            case .running:
                // Running at walking speed?
                if speed > 0 && speed < 2.0 {  // < 7.2 km/h
                    activityLevel = .walking
                } else {
                    activityLevel = .running
                }
            case .walking:
                // Walking fast? (> 2.5 m/s is ~9 km/h, basically running)
                if speed > 2.5 {
                    activityLevel = .running
                } else {
                    activityLevel = .walking
                }
            case .stationary, .unknown:
                // Global Speed Check for Ambiguous/Missing Data
                if speed > 10.0 {
                    activityLevel = .automotive
                } else if speed > 2.5 {
                    activityLevel = .running
                } else if speed > 0.5 {
                    activityLevel = .walking
                } else {
                    activityLevel = .stationary
                }
            }
        }

        // Final Noise Check using Distance and Duration
        if distance < 5.0 && duration > 10.0 {
            // Optimization: Bitwise mask for [walking(2), running(4), cycling(8)] = 14 (0xE)
            if (activityLevel.rawValue & 0xE) != 0 {
                activityLevel = .stationary
                // We're overriding motion based on lack of distance
                isPhysicsOverride = true
            }
        }

        if distance < 1.0 && activityLevel != .automotive {
            activityLevel = .stationary
            isPhysicsOverride = true
        }

        // 3. O(1) Lookup
        let actIdx = activityIndex(for: activityLevel)
        let index = (actIdx << 11) | minutesFromMidnight

        let result = lookupTable[index & 0x3FFF]

        // 4. Calculate Final Probability
        // Base probability comes from the matched Rule (result.probability)

        var confidenceMultiplier: Double

        if isPhysicsOverride {
            // If physics dictated the activity (e.g. speed > human limits), we trust that implicitly.
            confidenceMultiplier = 1.0
        } else {
            // Otherwise, we scale based on the sensor confidence
            switch confidence {
            case .high: confidenceMultiplier = 1.0
            case .medium: confidenceMultiplier = 0.8
            case .low: confidenceMultiplier = 0.5
            }
        }

        // Activity Specificity Weight
        // Certain activities are strong indicators of specific vibes (e.g. Running -> Energetic).
        // Others (Stationary) are ambiguous and rely heavily on time context, so we dampen validty slightly.
        let activityPrecision: Double

        // Mask for [Automotive(16), Cycling(8), Running(4)] = 28 (0x1C)
        if (activityLevel.rawValue & 0x1C) != 0 {
            activityPrecision = 1.0
        } else if (activityLevel.rawValue & 2) != 0 {  // Walking(2)
            activityPrecision = 0.9
        } else {
            activityPrecision = 0.8  // Stationary is inherently ambiguous
        }

        // Duration Stability Weight
        // Transient activities (< 1 min) are less reliable than sustained ones.
        // Long duration activities (> 10 mins) are highly reliable "Vibes".
        let durationWeight: Double
        if duration < 60.0 {
            durationWeight = 0.7  // Transient/Noise penalty
        } else {
            durationWeight = 1.0  // Standard
        }

        // Weighted Average for Robustness
        // Multiplicative can be too punitive (e.g. 0.9 * 0.9 * 0.9 = 0.72).
        // Weighted Average preserves high likelihood signals while acknowledging weaknesses.

        // Dynamic Weights (Total: 10.0)
        // If confidence is LOW, we shift weight heavily to the sensor confidence itself.
        // "Uncertainty Dominance": When data is bad, the uncertainty is the strongest signal.

        let wLikelihood: Double = (confidence == .low) ? 2.0 : 3.5
        let wConfidence: Double = (confidence == .low) ? 5.0 : 3.5
        let wActivity = 2.0
        let wDuration = 1.0

        // Optimization: Removed Division by constant 10.0
        // totalWeight is invariant (3.5+3.5+2+1 = 10, 2+5+2+1 = 10).
        // Multiply by 0.1 is significantly faster than division.

        let weightedSum =
            (result.probability * wLikelihood) + (confidenceMultiplier * wConfidence)
            + (activityPrecision * wActivity) + (durationWeight * wDuration)

        var finalProbability = min(weightedSum * 0.1, 1.0)

        // Contextual Plausibility Check (Soft Logic)
        // Adjust for unlikely times. E.g. "Focus" at 4 AM is rarer than "Sleep".
        // This acts as a "Common Sense" filter on top of the raw data.
        if hour >= 1 && hour <= 4 {
            if result.vibe == .focus {
                finalProbability *= 0.8  // Deep work at 3 AM is rare
            } else if result.vibe == .energetic {
                finalProbability *= 0.9  // 3 AM run? Possible but less likely.
            }
        }

        // Weekend Override (Heuristic)
        // If it's the weekend, "Focus" is likely "Chill" or "Personal Project" (Chill/Energetic).
        // Since we don't have separate weekday/weekend tables, we patch this here.

        // Optimization: Use a thread-safe cached calendar for this specific operation
        // or just re-use the current calendar since we are inside a static method.
        // Given this is static, we can't easily hold state without locks.
        // However, Calendar(identifier: .gregorian) is cheaper than Calendar.current (which tracks prefs).
        // For weekday check, we just need Gregorian.

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = Self.timeZone

        let weekday = calendar.component(.weekday, from: timestamp)  // 1=Sun, 7=Sat
        if (weekday == 1 || weekday == 7) && result.vibe == .focus {
            // Downgrade Focus to Chill on weekends unless confidence is extremely high?
            // Or just swap it. Test expects Chill.
            return (.chill, finalProbability * 0.9)
        }

        return (result.vibe, finalProbability)
    }
}
