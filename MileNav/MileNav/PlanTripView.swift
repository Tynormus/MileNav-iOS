import SwiftUI
import MapKit

/// "Where to?" — search a destination, preview the route, start driving.
struct PlanTripView: View {
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var nav: NavigationEngine
    @EnvironmentObject private var preferences: AppPreferences
    @StateObject private var search = PlaceSearch()
    @State private var query = ""
    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search address or place", text: $query)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                        .onChange(of: query) { _, newValue in
                            search.updateQuery(newValue)
                        }
                        .onSubmit {
                            search.search(query: query,
                                          near: locationManager.currentLocation?.coordinate) { item in
                                if let item = item {
                                    nav.setDestination(item)
                                }
                            }
                        }
                    if !query.isEmpty {
                        Button {
                            query = ""
                            nav.clearDestination()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                .padding()

                if nav.destination == nil {
                    suggestionsList
                } else {
                    routePreview
                }
            }
            .navigationTitle("Navigate")
            .onAppear {
                if !locationManager.isAuthorized {
                    locationManager.requestWhenInUse()
                }
                locationManager.startUpdating()
                // Routing preferences may have changed in Settings since this
                // route was calculated — refresh it so Avoid Tolls/Highways
                // take effect.
                if nav.destination != nil, !nav.isNavigating {
                    nav.calculateRoute()
                }
            }
            .onChange(of: locationManager.currentLocation?.coordinate.latitude) { _, _ in
                // First location fix arrived after a destination was picked —
                // the route couldn't be calculated until now.
                if nav.destination != nil, nav.route == nil {
                    nav.calculateRoute()
                }
            }
        }
    }

    private var suggestionsList: some View {
        Group {
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                ContentUnavailableView(
                    "Where are you headed?",
                    systemImage: "map.fill",
                    description: Text("Type an address or place name. When you arrive, MileNav asks if the trip was Work or Personal and logs the miles."))
            } else {
                List(search.suggestions, id: \.self) { suggestion in
                    Button {
                        search.resolve(suggestion) { item in
                            if let item = item {
                                query = suggestion.title
                                nav.setDestination(item)
                            }
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.title)
                                .foregroundStyle(.primary)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private var routePreview: some View {
        VStack(spacing: 16) {
            Map(position: $cameraPosition) {
                if let route = nav.route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 5)
                }
                if let coord = nav.destinationCoordinate {
                    Marker(nav.destinationName, coordinate: coord)
                }
                UserAnnotation()
            }
            .mapStyle(preferences.mapStyleOption.mapStyle)
            .frame(height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)
            .onChange(of: nav.route?.distance) { _, _ in
                if let route = nav.route {
                    cameraPosition = .rect(route.polyline.boundingMapRect)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(nav.destinationName)
                    .font(.headline)
                Text(nav.destinationAddress)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let route = nav.route {
                    Text("\(Formatters.miles(route.distance)) · \(Formatters.duration(route.expectedTravelTime)) · arrive \(nav.arrivalTime, format: .dateTime.hour().minute())")
                        .font(.subheadline.weight(.semibold))
                        .padding(.top, 2)
                    if route.hasTolls {
                        Label(preferences.avoidTolls
                              ? "This route still uses toll roads — no toll-free route was found"
                              : "This route uses toll roads",
                              systemImage: "dollarsign.circle.fill")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    if preferences.avoidTolls || preferences.avoidHighways {
                        Text("Routing: \(preferences.avoidTolls ? "avoiding tolls" : "")\(preferences.avoidTolls && preferences.avoidHighways ? " · " : "")\(preferences.avoidHighways ? "avoiding highways" : "")")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else if let error = nav.routeError {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                } else {
                    ProgressView("Finding the best route…")
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)

            Button {
                nav.startNavigation()
            } label: {
                Label("Start Navigation", systemImage: "location.north.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(nav.route == nil)
            .padding(.horizontal)

            Button("Change destination", role: .destructive) {
                query = ""
                nav.clearDestination()
            }
            Spacer()
        }
    }
}
