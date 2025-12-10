//
//  MotionDataCollector.swift
//  DataCollector
//
//  Created by Sijo on 04/12/25.
//

import CoreMotion
import Foundation
import Logger

/// A wrapper around `CMMotionActivityManager` that provides an async stream of activity updates.
///
/// `MotionDataCollector` manages the authorization status and lifecycle of motion updates.
///   activity objects across concurrency boundaries (as `CMMotionActivity` is not yet Sendable
///   but is effectively immutable).
@MainActor
final class MotionDataCollector {
    // ...
    private let log = LogContext("MDAT")
    /// A stream of raw CMMotionActivity updates.
    var rawActivityUpdates: AsyncStream<CMMotionActivity> {
        _rawActivityStream
    }

    private(set) var lastActivity: CMMotionActivity = .init()

    private let (_rawActivityStream, _rawActivityContinuation) = AsyncStream<CMMotionActivity>
        .makeStream()

    private var authorizationStatus: CMAuthorizationStatus =
        CMMotionActivityManager.authorizationStatus()
    private let motionActivityManager = CMMotionActivityManager()

    private var isCollecting = false

    init() {
        log.inited()
    }

    // MARK: - Authorization

    /// Requests permission to access motion data.
    /// This method triggers the system permission prompt by querying for past activity.
    /// It uses a continuation to await the completion of the query before checking the status.
    func requestAuthorization() {
        Task { await requestPermission() }
    }

    /// Internal async helper that performs the query and resumes when the callback fires.
    private func requestPermission() async {
        let now = Date()
        // Query past activity to trigger the permission dialog.
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            motionActivityManager.queryActivityStarting(
                from: now.addingTimeInterval(-100),
                to: now,
                to: .main
            ) { _, _ in
                continuation.resume()
            }
        }
        // After the query completes, re‑evaluate the authorization status.
        checkAuthorization()
    }

    private func checkAuthorization() {
        authorizationStatus = CMMotionActivityManager.authorizationStatus()
        if authorizationStatus == .authorized {
            start()
        } else {
            log.warning("Motion permission not granted.")
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
            log.warning("Motion updates are already active.")
            return
        }

        guard CMMotionActivityManager.isActivityAvailable() else {
            log.warning("Motion activity is not available on this device.")
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
        lastActivity = activity
        Task { [weak self] in
            guard let self else { return }
            _rawActivityContinuation.yield(activity)
        }
    }

    deinit {
        log.deinited()
    }
}
