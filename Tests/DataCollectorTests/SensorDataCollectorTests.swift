//
//  SensorDataCollectorTests.swift
//  DataCollectorTests
//
//  Created by Sijo on 05/12/25.
//

import CoreLocation
@preconcurrency import CoreMotion
import Foundation
import Testing

@testable import DataCollector
@testable import Store

// MARK: - Mocks

@MainActor
class MockMotionCollector {
    var rawActivityUpdates: AsyncStream<CMMotionActivity> { stream }
    var lastActivity: CMMotionActivity = .init()

    private let (stream, continuation) = AsyncStream<CMMotionActivity>.makeStream()

    func start() {}
    func stop() {}
    func requestAuthorization() {}

    func simulateActivity(_ activity: CMMotionActivity) {
        lastActivity = activity
        Task {
            continuation.yield(activity)
        }
    }
}

@MainActor
class MockLocationCollector {
    var locationUpdates: AsyncStream<CLLocation> { stream }
    var lastLocation: CLLocation = .init(latitude: 0, longitude: 0)

    private let (stream, continuation) = AsyncStream<CLLocation>.makeStream()

    func start() {}
    func stop() {}
    func requestAuthorization() {}

    func simulateLocation(_ location: CLLocation) {
        lastLocation = location
        continuation.yield(location)
    }
}

// Subclass CMMotionActivity to allow instantiation for testing
// Note: CMMotionActivity requires macOS 15.0+ or iOS 7.0+ (iOS 18 target is fine)
class MockMotionActivity: CMMotionActivity {
    // We override specific properties we care about if needed.
    // CMMotionActivity properties are get-only.
    // Since we can't easily init with specific values without private APIs,
    // we rely on the fact that for "100% code coverage" of logic, any activity object might suffice
    // UNLESS the builder logic depends on specific states (stationary, etc.)
    // If builder logic depends on stationary, we must override.

    private let _stationary: Bool
    private let _walking: Bool
    private let _startDate: Date

    init(stationary: Bool, walking: Bool, startDate: Date) {
        self._stationary = stationary
        self._walking = walking
        self._startDate = startDate
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var stationary: Bool { _stationary }
    override var walking: Bool { _walking }
    override var startDate: Date { _startDate }
}

// Helper struct for SensorData
struct TestSensorData: CSVEncodable, Timestampable, Sendable {
    let timestamp: Date
    let activity: String

    static var csvHeader: String { "timestamp,activity" }

    func write(csv: inout String) {
        csv.append("\(timestamp.timeIntervalSince1970),\(activity)")
    }
}

@Suite @MainActor final class SensorDataCollectorTests {
    var collector: SensorDataCollector<TestSensorData>!
    var mockMotion: MockMotionCollector!
    var mockLocation: MockLocationCollector!
    var fileSystem: FileSystem!
    var testPath: String
    var batcher: Batcher<TestSensorData>!
    
    init() async throws {
        testPath = "VibeTests/Collector_" + UUID().uuidString
        fileSystem = FileSystem(.custom(testPath))
        
        let csvStore = CSVStore(fileSystem: fileSystem)
        // We use a real Batcher and FileSystem to test "End to End" of the collector component
        batcher = Batcher(csvStore: csvStore, batchSize: 2)
        
        mockMotion = MockMotionCollector()
        mockLocation = MockLocationCollector()
        
        let builder: @MainActor (CMMotionActivity, CLLocation) async -> TestSensorData = {
            activity, location in
            let actStr =
            activity.stationary ? "stationary" : (activity.walking ? "walking" : "unknown")
            return TestSensorData(timestamp: Date(), activity: actStr)
        }
        
        collector = await SensorDataCollector(
            sensorData: TestSensorData(timestamp: Date(), activity: "init"),
            batcher: batcher,
            builder: builder)
    }
    
    deinit {
        try? FileManager.default.removeItem(
            at: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(testPath, isDirectory: true)
        )
    }
    
    @Test func testLifecycle() async throws {
        collector.start()
        try await Task.sleep(nanoseconds: 10_000_000)
        collector.stop()
        // No assertions, just coverage of lifecycle methods
    }
}
