import Foundation
import CoreLocation

/// Owns Core Location: authorization, the current position, and the
/// GPS odometer that measures a drive's actual miles while navigating.
final class LocationManager: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published private(set) var isTracking = false
    @Published private(set) var trackedDistanceMeters: Double = 0

    /// Called for every location update (the navigation engine hooks this).
    var onLocationUpdate: ((CLLocation) -> Void)?

    private let manager = CLLocationManager()
    private var lastTrackedLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.activityType = .automotiveNavigation
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        authorizationStatus = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    /// "Always" lets tracking continue with the screen locked mid-drive;
    /// iOS only offers the upgrade after When-In-Use has been granted.
    func requestAlways() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdating() {
        guard isAuthorized else { return }
        manager.startUpdatingLocation()
    }

    /// Starts the mileage odometer for a new drive.
    func startTracking() {
        trackedDistanceMeters = 0
        lastTrackedLocation = nil
        isTracking = true
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.startUpdatingLocation()
    }

    func stopTracking() {
        isTracking = false
        manager.allowsBackgroundLocationUpdates = false
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async {
            self.authorizationStatus = status
            if self.isAuthorized {
                self.manager.startUpdatingLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            DispatchQueue.main.async {
                self.currentLocation = location
            }
            onLocationUpdate?(location)
            guard isTracking else { continue }
            // Reject poor fixes so parked-car GPS drift doesn't add fake miles.
            guard location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 65 else { continue }
            if let last = lastTrackedLocation {
                let segment = location.distance(from: last)
                let dt = location.timestamp.timeIntervalSince(last.timestamp)
                guard dt > 0 else { continue }
                let speed = segment / dt
                if segment >= 4, speed <= 70 {
                    // Plausible driving segment — count it.
                    DispatchQueue.main.async {
                        self.trackedDistanceMeters += segment
                    }
                    lastTrackedLocation = location
                }
                // segment < 4 m is jitter at a standstill; a segment implying
                // > 70 m/s is a GPS jump. Both are ignored and the anchor stays.
            } else {
                lastTrackedLocation = location
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Keep the last known location; the next update re-checks everything.
    }
}
