import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]
    @EnvironmentObject private var locationManager: LocationManager
    var goNavigate: () -> Void

    private func miles(_ category: TripCategory, in period: Calendar.Component? = nil) -> Double {
        trips
            .filter { trip in
                guard trip.category == category else { return false }
                guard let period = period else { return true }
                return Calendar.current.isDate(trip.startDate, equalTo: Date(), toGranularity: period)
            }
            .reduce(0) { $0 + $1.distanceMiles }
    }

    private var unclassifiedCount: Int {
        trips.filter { $0.category == .unclassified }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !locationManager.isAuthorized {
                        Button {
                            locationManager.requestWhenInUse()
                        } label: {
                            Label("MileNav needs location access to navigate and track miles. Tap to allow.",
                                  systemImage: "location.slash.fill")
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 12) {
                        StatCard(title: "Work", subtitle: "all time",
                                 miles: miles(.work),
                                 systemImage: TripCategory.work.iconName, tint: .blue)
                        StatCard(title: "Personal", subtitle: "all time",
                                 miles: miles(.personal),
                                 systemImage: TripCategory.personal.iconName, tint: .green)
                    }
                    HStack(spacing: 12) {
                        StatCard(title: "Work", subtitle: "this month",
                                 miles: miles(.work, in: .month),
                                 systemImage: TripCategory.work.iconName, tint: .blue)
                        StatCard(title: "Personal", subtitle: "this month",
                                 miles: miles(.personal, in: .month),
                                 systemImage: TripCategory.personal.iconName, tint: .green)
                    }

                    Button(action: goNavigate) {
                        Label("Navigate & Log a Trip", systemImage: "location.north.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if unclassifiedCount > 0 {
                        Text("\(unclassifiedCount) trip\(unclassifiedCount == 1 ? "" : "s") still need a category — swipe a trip in the Log tab to set Work or Personal.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !trips.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent trips")
                                .font(.headline)
                            ForEach(trips.prefix(5)) { trip in
                                NavigationLink {
                                    TripDetailView(trip: trip)
                                } label: {
                                    TripRow(trip: trip)
                                }
                                .buttonStyle(.plain)
                                if trip.id != trips.prefix(5).last?.id {
                                    Divider()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    } else {
                        Text("No trips logged yet. Your drives will show up here with their miles split into Work and Personal.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle("MileNav")
        }
    }
}

struct StatCard: View {
    let title: String
    let subtitle: String
    let miles: Double
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Text(String(format: "%.1f mi", miles))
                .font(.system(size: 30, weight: .bold, design: .rounded))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
