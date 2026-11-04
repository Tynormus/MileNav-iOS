import SwiftUI
import SwiftData

/// MileNav — turn-by-turn navigation that logs every drive as Work or Personal miles.
///
/// Flow: search a destination, get a route, start navigation (voice-guided,
/// GPS-tracked). When you arrive (or end the trip early) the app asks
/// "Work or Personal?" and saves the trip with its actual miles driven.
/// Dashboard and Log tabs total the miles per category.
@main
struct MileNavApp: App {
    @StateObject private var locationManager: LocationManager
    @StateObject private var navEngine: NavigationEngine

    init() {
        // Shared instances: the CarPlay scene delegate (when active) drives
        // the very same engine the phone UI is using.
        _locationManager = StateObject(wrappedValue: AppServices.shared.locationManager)
        _navEngine = StateObject(wrappedValue: AppServices.shared.navEngine)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(navEngine)
                .environmentObject(AppServices.shared.preferences)
        }
        .modelContainer(for: Trip.self)
    }
}
