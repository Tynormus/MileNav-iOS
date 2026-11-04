import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var nav: NavigationEngine
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(goNavigate: { selectedTab = 1 })
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(0)

            PlanTripView()
                .tabItem { Label("Navigate", systemImage: "map.fill") }
                .tag(1)

            TripListView()
                .tabItem { Label("Log", systemImage: "list.bullet.rectangle") }
                .tag(2)
        }
        .fullScreenCover(isPresented: $nav.isPresentingNavigation) {
            ActiveNavigationView()
        }
        .sheet(item: $nav.pendingClassification) { draft in
            ClassifyTripView(draft: draft)
        }
    }
}
