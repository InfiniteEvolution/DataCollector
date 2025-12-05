//
//  MotionDataCollector.swift
//  DataCollector
//
//  Created by Antigravity on 04/12/25.
//

import CoreMotion
import Foundation
import Logger

@Observable
@MainActor
final class MotionDataCollector {
    private(set) var activityType: CMActivityType = .unknown
    private(set) var activityStartTime: Date = Date()

    /// A stream of activity updates.
    public var activityUpdates: AsyncStream<CMActivityType> {
        _activityStream
    }

    private let (_activityStream, _activityContinuation) = AsyncStream<CMActivityType>.makeStream()

    private var authorizationStatus: CMAuthorizationStatus =
        CMMotionActivityManager.authorizationStatus()
    private let motionActivityManager = CMMotionActivityManager()

    private let log = LogContext("MDAT")
    private var isCollecting = false

    public init() {}

    // MARK: - Authorization

    /// Requests permission to access motion data.
    ///
    /// This method triggers the system permission prompt by querying for past activity.
    /// If authorization changes, the `authorizationStatus` property will update, potentially
    /// triggering `start()` via its property observer.
    func requestAuthorization() {
        let now = Date()
        // Querying for past activity triggers the permission prompt if not yet determined.
        motionActivityManager.queryActivityStarting(from: now, to: now, to: .main) {
            [weak self] _, _ in
            Task { @MainActor in
                self?.checkAuthorization()
            }
        }
    }

    private func checkAuthorization() {
        authorizationStatus = CMMotionActivityManager.authorizationStatus()
        if authorizationStatus == .authorized {
            start()
        }
    }

    // MARK: - Collection Control

    /// Starts motion activity updates.
    ///
    /// If authorization is not yet granted, this method will request it.
    func start() {
        guard authorizationStatus == .authorized else {
            log.warning("Motion permission not authorized. Requesting access...")
            requestAuthorization()
            return
        }

        guard !isCollecting else {
            log.notice("Motion updates are already active.")
            return
        }

        guard CMMotionActivityManager.isActivityAvailable() else {
            log.error("Motion activity is not available on this device.")
            return
        }

        log.info("Starting motion activity updates.")
        isCollecting = true

        motionActivityManager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let activity else { return }
            self.updateActivity(activity)
        }
    }

    /// Stops motion activity updates.
    func stop() {
        guard isCollecting else { return }
        log.info("Stopping motion activity updates.")
        motionActivityManager.stopActivityUpdates()
        isCollecting = false
    }

    // MARK: - Helpers

    private func updateActivity(_ activity: CMMotionActivity) {
        let newActivityType: CMActivityType
        if activity.confidence == .low {
            newActivityType = .unknown
        } else if activity.stationary {
            newActivityType = .stationary
        } else if activity.walking {
            newActivityType = .walking
        } else if activity.running {
            newActivityType = .running
        } else if activity.automotive {
            newActivityType = .automotive
        } else if activity.cycling {
            newActivityType = .cycling
        } else {
            newActivityType = .unknown
        }

        if newActivityType != activityType {
            self.activityType = newActivityType
            // Yield the new activity type to the stream
            _activityContinuation.yield(newActivityType)
        }

        if activityStartTime != activity.startDate {
            activityStartTime = activity.startDate
        }
    }
}
