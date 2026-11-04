import SwiftUI
import SwiftData
import MapKit

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showDeleteConfirm = false

    var body: some View {
        Form {
            if trip.hasCoordinates {
                Section {
                    Map(position: $cameraPosition) {
                        Marker("Start", coordinate: trip.startCoordinate)
                            .tint(.green)
                        Marker("End", coordinate: trip.endCoordinate)
                            .tint(.red)
                        MapPolyline(coordinates: [trip.startCoordinate, trip.endCoordinate])
                            .stroke(.blue.opacity(0.6), lineWidth: 3)
                    }
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
                }
            }

            Section("Category") {
                Picker("Category", selection: categoryBinding) {
                    ForEach(TripCategory.allCases) { category in
                        Label(category.rawValue, systemImage: category.iconName)
                            .tag(category)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Trip") {
                LabeledContent("Date", value: trip.startDate.formatted(date: .abbreviated, time: .shortened))
                LabeledContent("Miles", value: String(format: "%.2f mi", trip.distanceMiles))
                LabeledContent("Drive time", value: Formatters.duration(trip.duration))
                if trip.trackedDistanceMeters > 0 {
                    LabeledContent("GPS-tracked", value: Formatters.miles(trip.trackedDistanceMeters))
                }
                if trip.routeDistanceMeters > 0 {
                    LabeledContent("Planned route", value: Formatters.miles(trip.routeDistanceMeters))
                }
            }

            Section("Route") {
                LabeledContent("From") {
                    Text(trip.startAddress)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("To") {
                    Text(trip.endAddress)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Note") {
                TextField("Add a note", text: $trip.note, axis: .vertical)
            }

            Section {
                Button("Delete Trip", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .navigationTitle(trip.destinationName.isEmpty ? "Trip" : trip.destinationName)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this trip?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                modelContext.delete(trip)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var categoryBinding: Binding<TripCategory> {
        Binding(
            get: { trip.category },
            set: { newValue in
                trip.category = newValue
                try? modelContext.save()
            })
    }
}
