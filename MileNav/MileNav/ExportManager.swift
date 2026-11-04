import Foundation

/// Builds the CSV export of the trip log — handy at tax time or for
/// mileage reimbursement (date, route, miles, category).
enum ExportManager {
    static func csv(for trips: [Trip]) -> String {
        var lines = ["Start Time,End Time,From,To,Miles,Category,Duration (min),Note"]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        for trip in trips.sorted(by: { $0.startDate < $1.startDate }) {
            let row = [
                formatter.string(from: trip.startDate),
                formatter.string(from: trip.endDate),
                escape(trip.startAddress),
                escape(trip.endAddress),
                String(format: "%.2f", trip.distanceMiles),
                trip.category.rawValue,
                String(format: "%.0f", trip.duration / 60),
                escape(trip.note),
            ]
            lines.append(row.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    static func exportFileURL(trips: [Trip]) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("MileNav-trips.csv")
        try? csv(for: trips).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
