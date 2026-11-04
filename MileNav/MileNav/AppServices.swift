import Foundation

/// Shared app services, so both the SwiftUI app and the CarPlay scene
/// delegate drive the SAME location manager and navigation engine —
/// a route started on the phone is the route CarPlay mirrors.
final class AppServices {
    static let shared = AppServices()

    let locationManager: LocationManager
    let navEngine: NavigationEngine

    private init() {
        let manager = LocationManager()
        locationManager = manager
        navEngine = NavigationEngine(locationManager: manager)
    }
}
