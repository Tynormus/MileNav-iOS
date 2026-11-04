import Foundation
import CoreLocation
import MapKit

enum Formatters {
    /// "842 ft" under a tenth of a mile, "3.4 mi" under 10, "128 mi" above.
    static func miles(_ meters: Double) -> String {
        let milesValue = meters / 1609.344
        if milesValue < 0.1 { return String(format: "%.0f ft", meters * 3.28084) }
        if milesValue < 10 { return String(format: "%.1f mi", milesValue) }
        return String(format: "%.0f mi", milesValue)
    }

    static func maneuverDistance(_ meters: Double) -> String {
        if meters < 160 { return String(format: "%.0f ft", meters * 3.28084) }
        return String(format: "%.1f mi", meters / 1609.344)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h) hr \(m) min" }
        if m > 0 { return "\(m) min" }
        return "< 1 min"
    }
}

/// "742 W Main St, Placentia, CA 92870"-style single line from a placemark.
func formattedAddress(_ placemark: CLPlacemark) -> String {
    var parts: [String] = []
    if let name = placemark.name, !name.isEmpty {
        parts.append(name)
    }
    let street = [placemark.subThoroughfare, placemark.thoroughfare]
        .compactMap { $0 }
        .joined(separator: " ")
    if !street.isEmpty, placemark.name != street {
        parts.append(street)
    }
    if let locality = placemark.locality {
        parts.append(locality)
    }
    let stateZip = [placemark.administrativeArea, placemark.postalCode]
        .compactMap { $0 }
        .joined(separator: " ")
    if !stateZip.isEmpty {
        parts.append(stateZip)
    }
    // De-duplicate while keeping order (a business name can repeat the street line).
    var seen = Set<String>()
    let unique = parts.filter { seen.insert($0).inserted }
    return unique.isEmpty ? "Unknown location" : unique.joined(separator: ", ")
}

func mapItemTitle(_ item: MKMapItem) -> String {
    if let name = item.name, !name.isEmpty { return name }
    return formattedAddress(item.placemark)
}

/// Lowercases the first letter so "Turn left…" can follow "In 0.2 mi, …".
func sentenceFragment(_ text: String) -> String {
    guard let first = text.first else { return text }
    return first.lowercased() + text.dropFirst()
}

/// Shortest distance in meters from a location to a sampled polyline
/// (used for off-route detection).
func distanceToPolyline(_ location: CLLocation, polyline: MKPolyline) -> CLLocationDistance {
    let count = polyline.pointCount
    guard count > 0 else { return .greatestFiniteMagnitude }
    let points = polyline.points()
    let stride = max(1, count / 400)
    var best = CLLocationDistance.greatestFiniteMagnitude
    var i = 0
    while i < count {
        let c = points[i].coordinate
        let d = location.distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
        if d < best { best = d }
        i += stride
    }
    let last = points[count - 1].coordinate
    let dLast = location.distance(from: CLLocation(latitude: last.latitude, longitude: last.longitude))
    return min(best, dLast)
}
