import SwiftUI
import SwiftData

struct TripRow: View {
    let trip: Trip

    private var tint: Color {
        switch trip.category {
        case .work: return .blue
        case .personal: return .green
        case .unclassified: return .orange
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: trip.category.iconName)
                .foregroundStyle(tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(trip.destinationName.isEmpty ? trip.endAddress : trip.destinationName)
                    .font(.headline)
                    .lineLimit(1)
                Text(trip.startDate, format: .dateTime.month().day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f mi", trip.distanceMiles))
                    .font(.headline)
                Text(trip.category.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct TripListView: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]
    @Environment(\.modelContext) private var modelContext
    @State private var filter: TripCategory? = nil
    @State private var showManualAdd = false
    @State private var exportURL: URL?

    private var filtered: [Trip] {
        guard let filter = filter else { return trips }
        return trips.filter { $0.category == filter }
    }

    private var filteredMiles: Double {
        filtered.reduce(0) { $0 + $1.distanceMiles }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $filter) {
                    Text("All").tag(TripCategory?.none)
                    ForEach(TripCategory.allCases) { category in
                        Text(category.rawValue).tag(TripCategory?.some(category))
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                Text("\(filtered.count) trip\(filtered.count == 1 ? "" : "s") · \(String(format: "%.1f", filteredMiles)) miles")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)

                if filtered.isEmpty {
                    ContentUnavailableView(
                        "No trips here yet",
                        systemImage: "car.fill",
                        description: Text("Trips you navigate to will be logged here, split into Work and Personal miles."))
                } else {
                    List {
                        ForEach(filtered) { trip in
                            NavigationLink {
                                TripDetailView(trip: trip)
                            } label: {
                                TripRow(trip: trip)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    trip.category = .work
                                    try? modelContext.save()
                                } label: {
                                    Label("Work", systemImage: TripCategory.work.iconName)
                                }
                                .tint(.blue)
                                Button {
                                    trip.category = .personal
                                    try? modelContext.save()
                                } label: {
                                    Label("Personal", systemImage: TripCategory.personal.iconName)
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    modelContext.delete(trip)
                                    try? modelContext.save()
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Trip Log")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if let exportURL = exportURL {
                        ShareLink(item: exportURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    Button {
                        showManualAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .onAppear { exportURL = ExportManager.exportFileURL(trips: trips) }
            .onChange(of: trips.count) { _, _ in
                exportURL = ExportManager.exportFileURL(trips: trips)
            }
            .sheet(isPresented: $showManualAdd) {
                ManualTripView()
            }
        }
    }
}

/// Log a drive by hand — for trips that weren't navigated in the app.
struct ManualTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var destination = ""
    @State private var fromAddress = ""
    @State private var toAddress = ""
    @State private var milesText = ""
    @State private var category: TripCategory = .work
    @State private var date = Date()

    private var miles: Double? {
        Double(milesText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip") {
                    TextField("Destination name", text: $destination)
                    TextField("From", text: $fromAddress)
                    TextField("To", text: $toAddress)
                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                Section("Miles") {
                    TextField("Miles driven (e.g. 12.4)", text: $milesText)
                        .keyboardType(.decimalPad)
                }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(TripCategory.allCases) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Add Trip Manually")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(miles == nil || (miles ?? 0) <= 0)
                }
            }
        }
    }

    private func save() {
        guard let miles = miles, miles > 0 else { return }
        let meters = miles * 1609.344
        let trip = Trip(
            startDate: date,
            endDate: date,
            startAddress: fromAddress.isEmpty ? "—" : fromAddress,
            endAddress: toAddress.isEmpty ? (destination.isEmpty ? "—" : destination) : toAddress,
            destinationName: destination,
            startCoordinate: .init(latitude: 0, longitude: 0),
            endCoordinate: .init(latitude: 0, longitude: 0),
            distanceMeters: meters,
            trackedDistanceMeters: 0,
            routeDistanceMeters: meters,
            category: category)
        modelContext.insert(trip)
        try? modelContext.save()
        dismiss()
    }
}
