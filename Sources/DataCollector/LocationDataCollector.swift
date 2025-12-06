//
//  LocationDataCollector.swift
//  DataCollector
//
//  Created by Antigravity on 04/12/25.
//

import CoreLocation
import Foundation
import Logger

@Observable
@MainActor
final class LocationDataCollector: NSObject {
    private(set) var lastLocation: CLLocation = .init(latitude: 0, longitude: 0)

    /// A stream of location updates.
    public var locationUpdates: AsyncStream<CLLocation> {
        _locationStream
    }

    private let (_locationStream, _locationContinuation) = AsyncStream<CLLocation>.makeStream()

    private var authorizationStatus: CLAuthorizationStatus = .notDetermined {
        didSet {
            guard
                authorizationStatus == .authorizedAlways
                    || authorizationStatus == .authorizedWhenInUse
            else {
                log.notice("Location authorization revoked or not granted.")
                stop()
                return
            }

            start()
        }
    }

    private let locationManager = CLLocationManager()
    private let log = LogContext("LDAT")
    private var isCollecting = false

    public override init() {
        super.init()
        setupLocationManager()
        authorizationStatus = locationManager.authorizationStatus
    }

    private func setupLocationManager() {
        locationManager.delegate = self

        // Fixed configuration (removed dynamic power mode switching)
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locationManager.distanceFilter = 10

        // Optimization: Set activity type for better battery efficiency
        locationManager.activityType = .fitness

        // Allow system to pause updates to save battery when stationary
        locationManager.pausesLocationUpdatesAutomatically = true

        // Safely enable background updates if configured
        if let connectionModes = Bundle.main.object(forInfoDictionaryKey: "UIBackgroundModes")
            as? [String],
            connectionModes.contains("location")
        {
            locationManager.allowsBackgroundLocationUpdates = true
        } else {
            log.warning(
                "Background location updates skipped: missing 'location' in UIBackgroundModes.")
        }
    }

    // MARK: - Authorization

    /// Requests permission to access location data.
    ///
    /// This method triggers the system permission prompt for "Always" authorization.
    func requestAuthorization() {
        locationManager.requestAlwaysAuthorization()
    }

    // MARK: - Collection Control

    /// Starts location updates.
    ///
    /// If authorization is not yet granted, this method will request it.
    func start() {
        if authorizationStatus != .authorizedAlways && authorizationStatus != .authorizedWhenInUse {
            log.warning("Location permission not authorized. Requesting access...")
            requestAuthorization()
            return
        }

        guard !isCollecting else {
            log.notice("Location updates are already active.")
            return
        }

        log.info("Starting location updates.")
        locationManager.startUpdatingLocation()
        isCollecting = true
    }

    /// Stops location updates.
    func stop() {
        guard isCollecting else {
            log.notice("Location updates are already stopped.")
            return
        }

        log.info("Stopping location updates.")
        locationManager.stopUpdatingLocation()
        isCollecting = false
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationDataCollector: @MainActor CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            log.notice("Received empty location update.")
            return
        }

        lastLocation = location

        _locationContinuation.yield(location)
    }

    func locationManager(
        _ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus
    ) {
        log.info("Authorization status \(manager.authorizationStatus.rawValue)")
        authorizationStatus = status
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        log.info("Authorization status changed: \(manager.authorizationStatus.rawValue)")
    }

    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        log.notice("Location updates paused.")
    }

    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        log.notice("Location updates resumed.")
    }

    func locationManager(
        _ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: (any Error)?
    ) {
        log.notice("Finished deferred updates with error: \(String(describing: error)).")
    }
}
