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
enum CMActivityType: String, Codable, CaseIterable, Sendable {
    case stationary
    case walking
    case running
    case automotive
    case cycling
    case unknown

    var id: Int {
        switch self {
        case .stationary: return 0
        case .walking: return 1
        case .running: return 2
        case .automotive: return 3
        case .cycling: return 4
        case .unknown: return 5
        }
    }

    // Optimization: Helper properties for cleaner code
    var isMoving: Bool {
        self == .walking || self == .running || self == .cycling || self == .automotive
    }

    var isHighIntensity: Bool {
        self == .running || self == .cycling
    }
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

    var id: Int {
        switch self {
        case .sleep: return 0
        case .morningRoutine: return 1
        case .energetic: return 2
        case .commute: return 3
        case .focus: return 4
        case .meal: return 5
        case .chill: return 6
        case .unknown: return 7
        }
    }

    public var title: String {
        self.rawValue.capitalized
    }
}

/// A synchronized snapshot of activity data.
///
/// `SensorData` represents a single point in time where both location and motion activity
/// were captured. It is optimized for storage using short JSON keys.
public struct SensorData: Codable, Identifiable, Timestampable, CSVEncodable, Sendable {
    // MARK: - ML Predictor
    /// Unique identifier for this sensor sample.
    public let id: UUID

    /// The timestamp for the data.
    public let timestamp: Date

    /// The total distance traveled in meters.
    let distance: Double

    /// The detected motion activity type.
    let activity: CMActivityType

    /// The start time of the current motion activity.
    let startTime: Date

    /// The duration of the current motion activity in seconds.
    let duration: TimeInterval

    /// The derived vibe or energy level.
    public internal(set) var vibe: Vibe  // Mutable for updating later if needed

    /// The probability/confidence of the vibe (0.0 - 1.0).
    ///
    /// This value represents the system's certainty in the predicted `vibe`.
    /// It is derived from either the ML model's class probability or the VibeEngine's rule confidence.
    var probability: Double

    /// The raw confidence reported by CMMotionActivity.
    let confidence: CMMotionActivityConfidence

    /// The speed of the user in meters per second.
    let speed: CLLocationSpeed

    // MARK: - Initializer

    /// Initializes a new sensor data snapshot with synchronous VibeEngine prediction.
    ///
    /// This initializer is typically used for the training data path where consistency
    /// with the rule-based Engine is required.
    ///
    /// - Parameters:
    ///   - motionActivity: The CMMotionActivity sample.
    ///   - location: The location context (current and recent).
    init(motionActivity: CMMotionActivity, location: Location) {
        self.id = UUID()
        self.timestamp = Date()
        self.startTime = motionActivity.startDate
        self.duration = self.timestamp.timeIntervalSince(self.startTime)
        self.distance = location.distance
        self.confidence = motionActivity.confidence
        self.speed = location.current.speed
        self.vibe = .unknown
        self.probability = .zero
        // Map Activity
        self.activity = {
            switch motionActivity.activityType {
            case .stationary: return .stationary
            case .walking: return .walking
            case .running: return .running
            case .automotive: return .automotive
            case .cycling: return .cycling
            case .unknown: return .unknown
            @unknown default: return .unknown
            }
        }()
    }

    // MARK: - CSVEncodable

    public static var csvHeader: String {
        "timestamp,distance,activity,startTime,duration,hour,dayOfWeek,vibe,probability"
    }

    public func write(csv output: inout String) {
        // ML-Ready: Unix Timestamps (Raw Numbers)
        let timestampString = String(timestamp.timeIntervalSince1970)

        // Extract Time Context for ML
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .weekday], from: timestamp)
        let hourString = String(components.hour ?? 0)
        let dayOfWeekString = String(components.weekday ?? 1)

        // ML-Ready Raw Values
        let distanceString = String(distance)
        let durationString = String(duration)
        let startTimeString = String(startTime.timeIntervalSince1970)
        let probabilityString = String(probability)

        output.append(timestampString)
        output.append(",")
        output.append(distanceString)
        output.append(",")
        output.append(String(activity.id))  // Integer ID
        output.append(",")
        output.append(startTimeString)
        output.append(",")
        output.append(durationString)
        output.append(",")
        output.append(hourString)
        output.append(",")
        output.append(dayOfWeekString)
        output.append(",")
        output.append(String(vibe.id))  // Integer ID
        output.append(",")
        output.append(probabilityString)
    }

    // MARK: - Integration

    /// Encapsulates location data for sensor readings.
    struct Location: Sendable {
        let current: CLLocation
        let recent: CLLocation

        init(current: CLLocation, recent: CLLocation) {
            self.current = current
            self.recent = recent
        }

        var distance: Double {
            current.distance(from: recent)
        }
    }

    // Internal init for testing
    init() {
        self.id = UUID()
        self.timestamp = Date()
        self.distance = .zero
        self.activity = .unknown
        self.startTime = .now
        self.duration = Date().timeIntervalSince(startTime)
        self.vibe = .unknown
        self.probability = .zero
        self.confidence = .low
        self.speed = .zero
    }
}

extension CMMotionActivity {
    @inline(__always)  // Optimization: Force inline for zero overhead
    var activityType: CMActivityType {
        if self.confidence == .low { return .unknown }
        if self.cycling { return .cycling }
        if self.running { return .running }
        if self.automotive { return .automotive }
        if self.walking { return .walking }
        if self.stationary { return .stationary }
        return .unknown
    }
}

extension CMMotionActivityConfidence: @retroactive Codable {}
