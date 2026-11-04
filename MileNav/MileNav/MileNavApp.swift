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
        let manager = LocationManager()
        _locationManager = StateObject(wrappedValue: manager)
        _navEngine = StateObject(wrappedValue: NavigationEngine(locationManager: manager))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationManager)
                .environmentObject(navEngine)
        }
        .modelContainer(for: Trip.self)
    }
}
