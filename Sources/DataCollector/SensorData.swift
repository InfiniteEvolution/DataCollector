//
//  SensorData.swift
//  DataCollector
//
//  Created by Sijo on 30/11/25.
//

import CoreLocation
import CoreMotion
import Foundation
import Store

// Custom enum to map CMMotionActivity since CMActivityType doesn't exist in SDK
public enum CMActivityType: String, Codable, CaseIterable, Sendable {
    case stationary
    case walking
    case running
    case automotive
    case cycling
    case unknown
}

/// Represents the "vibe" or energy level of the user based on their activity and time of day.
public enum Vibe: String, Codable, CaseIterable, Sendable {
    case sleep  // Late night stationary
    case morningRoutine  // Early morning stationary
    case energetic  // Fitness activities
    case commute  // Traveling
    case focus  // Work/Study
    case meal  // Breakfast/Lunch/Dinner
    case chill  // Relaxing
    case unknown

    public var title: String {
        self.rawValue.capitalized
    }

    public var description: String {
        switch self {
        case .sleep: return "Time to rest and recharge."
        case .morningRoutine: return "Starting the day fresh."
        case .energetic: return "Moving and grooving!"
        case .commute: return "On the move."
        case .focus: return "In the zone."
        case .meal: return "Fueling up."
        case .chill: return "Relaxing and unwinding."
        case .unknown: return "Vibe is a mystery."
        }
    }
}

/// A synchronized snapshot of activity data.
///
/// `SensorData` represents a single point in time where both location and motion activity
/// were captured. It is optimized for storage using short JSON keys.
public struct SensorData: Codable, Identifiable, Timestampable, CSVEncodable, Sendable {
    /// Unique identifier for this sensor sample.
    public let id: UUID

    /// The timestamp for the data.
    public let timestamp: Date

    /// The total distance traveled in meters.
    public let totalDistance: Double

    /// The detected motion activity type.
    public let motionActivity: CMActivityType

    /// The start time of the current motion activity.
    public let activityStartTime: Date

    /// The duration of the current motion activity in seconds.
    public let activityDuration: TimeInterval

    /// The derived vibe or energy level.
    public let vibe: Vibe

    /// Initializes a new sensor data snapshot.
    ///
    /// - Parameters:
    ///   - id: Unique identifier. Defaults to a new UUID.
    ///   - timestamp: The time of capture. Defaults to current date.
    ///   - totalDistance: The total distance traveled.
    ///   - motionActivity: The activity type from CoreMotion.
    ///   - activityStartTime: The start time of the current activity.
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        totalDistance: Double = 0.0,
        motionActivity: CMActivityType = .unknown,
        activityStartTime: Date = Date(),
        vibe: Vibe = .unknown
    ) {
        self.id = id
        self.timestamp = timestamp
        self.totalDistance = totalDistance
        self.motionActivity = motionActivity
        self.activityStartTime = activityStartTime
        activityDuration = timestamp.timeIntervalSince(activityStartTime)
        self.vibe = SensorData.deriveVibe(
            motion: motionActivity, distance: totalDistance, timestamp: timestamp)
    }

    // MARK: - CSVEncodable

    public static var csvHeader: String {
        "id,timestamp,totalDistance,motionActivity,activityStartTime,activityDuration,vibe"
    }

    // specific to ISO8601DateFormatter which is thread-safe for formatting.
    nonisolated(unsafe) private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        return formatter
    }()

    public func writeCSV(to output: inout String) {
        let timestampString = Self.dateFormatter.string(from: timestamp)
        let startTimeString = Self.dateFormatter.string(from: activityStartTime)

        output.append(id.uuidString)
        output.append(",")
        output.append(timestampString)
        output.append(",")
        output.append("\(totalDistance)")  // Double interpolation
        output.append(",")
        output.append(motionActivity.rawValue)
        output.append(",")
        output.append(startTimeString)
        output.append(",")
        output.append("\(activityDuration)")
        output.append(",")
        output.append(vibe.rawValue)
    }

    // Legacy property uses the efficient method via protocol extension default
    // keeping explicit here just in case, but can be removed if protocol default is sufficient.
    // Protocol default is sufficient. Removing explicit csvRow.

    // MARK: - Helper

    // MARK: - Vibe Derivation

    private static func deriveVibe(
        motion: CMActivityType, distance: Double, timestamp: Date
    ) -> Vibe {
        return VibeSystem.evaluate(motion: motion, distance: distance, timestamp: timestamp)
    }
}
