import SwiftUI
import SwiftData

/// Shown the moment a drive ends: "Was that Work or Personal?"
/// Picking one saves the trip with its miles under that category.
struct ClassifyTripView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let draft: TripDraft
    @State private var note = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 6) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 40))
                            .foregroundStyle(.blue)
                        Text("You arrived")
                            .font(.title2.weight(.bold))
                        Text(draft.destinationName)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    HStack(spacing: 12) {
                        summaryCard(title: "Miles", value: String(format: "%.2f", draft.loggedMiles))
                        summaryCard(title: "Drive time", value: Formatters.duration(draft.duration))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label(draft.startAddress, systemImage: "circle.fill")
                            .font(.subheadline)
                        Label(draft.endAddress, systemImage: "mappin.circle.fill")
                            .font(.subheadline)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    Text("What kind of trip was this?")
                        .font(.headline)

                    HStack(spacing: 12) {
                        categoryButton(.work, tint: .blue)
                        categoryButton(.personal, tint: .green)
                    }

                    TextField("Note (optional) — e.g. client visit, airport run", text: $note)
                        .textFieldStyle(.roundedBorder)

                    Button("Decide later") {
                        save(.unclassified)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding()
            }
            .navigationTitle("Log This Trip")
            .navigationBarTitleDisplayMode(.inline)
        }
        // The draft only exists in memory — don't let a swipe throw it away.
        .interactiveDismissDisabled(true)
    }

    private func summaryCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func categoryButton(_ category: TripCategory, tint: Color) -> some View {
        Button {
            save(category)
        } label: {
            VStack(spacing: 8) {
                Image(systemName: category.iconName)
                    .font(.system(size: 26))
                Text(category.rawValue)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
        .controlSize(.large)
    }

    private func save(_ category: TripCategory) {
        let trip = draft.makeTrip(category: category)
        trip.note = note
        modelContext.insert(trip)
        try? modelContext.save()
        dismiss()
    }
}
