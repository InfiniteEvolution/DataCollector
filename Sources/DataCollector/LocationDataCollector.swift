//
//  LocationDataCollector.swift
//  DataCollector
//
//  Created by Sijo on 04/12/25.
//

import CoreLocation
import Foundation
import Logger

@MainActor
final class LocationDataCollector: NSObject {
    private let log = LogContext("LDAT")
    /// The last known location.
    ///
    /// This property is updated on the Main Actor whenever a new location is received.
    /// It defaults to a zero coordinate if no location has been received yet.
    private(set) var lastLocation: CLLocation = .init(latitude: 0, longitude: 0)

    /// A stream of location updates.
    var locationUpdates: AsyncStream<CLLocation> {
        _locationStream
    }

    private let (_locationStream, _locationContinuation) = AsyncStream<CLLocation>.makeStream()

    private var authorizationStatus: CLAuthorizationStatus = .notDetermined {
        didSet {
            guard
                authorizationStatus == .authorizedAlways
                    || authorizationStatus == .authorizedWhenInUse
            else {
                log.warning("Location authorization revoked or not granted.")
                stop()
                return
            }

            start()
        }
    }
    
    private let locationManager = CLLocationManager()
    private var isCollecting = false
    
    /// Initializes a new location collector.
    ///
    /// This initializer configures the `CLLocationManager` with settings optimized for battery life,
    /// such as a 10-meter distance filter and `.fitness` activity type.
    override init() {
        super.init()
        setupLocationManager()
        authorizationStatus = locationManager.authorizationStatus
        log.inited()
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
            log.warning("Location updates are already active.")
            return
        }

        log.info("Starting location updates.")
        locationManager.startUpdatingLocation()
        isCollecting = true
    }

    /// Stops location updates.
    func stop() {
        guard isCollecting else {
            log.warning("Location updates are already stopped.")
            return
        }

        log.info("Stopping location updates.")
        locationManager.stopUpdatingLocation()
        isCollecting = false
    }

    deinit {
        log.deinited()
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationDataCollector: @MainActor CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            log.warning("Received empty location update.")
            return
        }
        
        lastLocation = location

        _locationContinuation.yield(location)
    }

    func locationManager(
        _ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus
    ) {
        authorizationStatus = status
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        log.info("Location updates paused.")
    }

    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        log.info("Location updates resumed.")
    }

    func locationManager(
        _ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: (any Error)?
    ) {
        log.error("Finished deferred updates with error: \(String(describing: error)).")
    }
}
