import SwiftUI
import MapKit

/// Full-screen guidance: follow-cam map, next-maneuver banner, trip stats,
/// and an End Trip button. Arrival is detected by the engine, which closes
/// this screen and opens the Work / Personal picker.
struct ActiveNavigationView: View {
    @EnvironmentObject private var nav: NavigationEngine
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var preferences: AppPreferences
    @State private var cameraPosition: MapCameraPosition = .userLocation(followsHeading: true, fallback: .automatic)
    @State private var showEndConfirm = false

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                if let route = nav.route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 6)
                }
                if let coord = nav.destinationCoordinate {
                    Marker(nav.destinationName, coordinate: coord)
                }
                UserAnnotation()
            }
            .mapStyle(preferences.mapStyleOption.mapStyle)
            .ignoresSafeArea()

            VStack {
                instructionBanner
                Spacer()
                bottomBar
            }
        }
        .onAppear {
            // Ask for the "Always" upgrade so tracking survives a locked screen.
            if locationManager.authorizationStatus == .authorizedWhenInUse {
                locationManager.requestAlways()
            }
        }
        .confirmationDialog("End this trip here?", isPresented: $showEndConfirm) {
            Button("End Trip & Log Miles", role: .destructive) {
                nav.endTripEarly()
            }
            Button("Keep Driving", role: .cancel) {}
        } message: {
            Text("The miles you've driven so far will still be logged.")
        }
    }

    private var instructionBanner: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(nav.currentInstruction.isEmpty ? "Heading to your destination" : nav.currentInstruction)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(3)
            if nav.nextStep != nil {
                Text("in \(Formatters.maneuverDistance(nav.distanceToNextManeuver))")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.85))
            }
            Text(nav.destinationName)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 0) {
                statBlock(value: nav.arrivalTime.formatted(date: .omitted, time: .shortened), label: "arrival")
                Divider().frame(height: 34)
                statBlock(value: Formatters.duration(nav.timeRemaining), label: "remaining")
                Divider().frame(height: 34)
                statBlock(value: Formatters.miles(nav.distanceRemaining), label: "to go")
                Divider().frame(height: 34)
                statBlock(value: Formatters.miles(locationManager.trackedDistanceMeters), label: "driven")
            }
            Button {
                showEndConfirm = true
            } label: {
                Text("End Trip")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private func statBlock(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
