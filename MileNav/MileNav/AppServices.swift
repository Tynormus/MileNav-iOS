import Foundation

/// Shared app services, so both the SwiftUI app and the CarPlay scene
/// delegate drive the SAME location manager and navigation engine —
/// a route started on the phone is the route CarPlay mirrors.
final class AppServices {
    static let shared = AppServices()

    let locationManager: LocationManager
    let preferences: AppPreferences
    let navEngine: NavigationEngine

    private init() {
        let manager = LocationManager()
        let prefs = AppPreferences()
        locationManager = manager
        preferences = prefs
        navEngine = NavigationEngine(locationManager: manager, preferences: prefs)
    }
}
