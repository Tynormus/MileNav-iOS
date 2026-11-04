import Foundation
import SwiftData
import CoreLocation

/// The two buckets Ty logs miles into (plus "not decided yet").
enum TripCategory: String, Codable, CaseIterable, Identifiable {
    case work = "Work"
    case personal = "Personal"
    case unclassified = "Unclassified"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .work: return "briefcase.fill"
        case .personal: return "house.fill"
        case .unclassified: return "questionmark.circle.fill"
        }
    }
}

/// One logged drive.
@Model
final class Trip {
    var id: UUID = UUID()
    var startDate: Date = Date()
    var endDate: Date = Date()
    var startAddress: String = ""
    var endAddress: String = ""
    var destinationName: String = ""
    var startLatitude: Double = 0
    var startLongitude: Double = 0
    var endLatitude: Double = 0
    var endLongitude: Double = 0
    /// The mileage that counts for this trip, in meters: strictly the
    /// GPS-measured miles as driven (never the planned route distance).
    var distanceMeters: Double = 0
    var trackedDistanceMeters: Double = 0
    var routeDistanceMeters: Double = 0
    var categoryRaw: String = TripCategory.unclassified.rawValue
    var note: String = ""

    var category: TripCategory {
        get { TripCategory(rawValue: categoryRaw) ?? .unclassified }
        set { categoryRaw = newValue.rawValue }
    }

    var distanceMiles: Double { distanceMeters / 1609.344 }
    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }

    var startCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: startLatitude, longitude: startLongitude)
    }
    var endCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: endLatitude, longitude: endLongitude)
    }
    var hasCoordinates: Bool { startLatitude != 0 || endLatitude != 0 }

    init(startDate: Date,
         endDate: Date,
         startAddress: String,
         endAddress: String,
         destinationName: String,
         startCoordinate: CLLocationCoordinate2D,
         endCoordinate: CLLocationCoordinate2D,
         distanceMeters: Double,
         trackedDistanceMeters: Double,
         routeDistanceMeters: Double,
         category: TripCategory,
         note: String = "") {
        self.startDate = startDate
        self.endDate = endDate
        self.startAddress = startAddress
        self.endAddress = endAddress
        self.destinationName = destinationName
        self.startLatitude = startCoordinate.latitude
        self.startLongitude = startCoordinate.longitude
        self.endLatitude = endCoordinate.latitude
        self.endLongitude = endCoordinate.longitude
        self.distanceMeters = distanceMeters
        self.trackedDistanceMeters = trackedDistanceMeters
        self.routeDistanceMeters = routeDistanceMeters
        self.categoryRaw = category.rawValue
        self.note = note
    }
}

/// Everything captured at the moment a drive ends, waiting for the
/// Work / Personal choice before it becomes a saved `Trip`.
struct TripDraft: Identifiable {
    let id = UUID()
    var startDate: Date
    var endDate: Date
    var startAddress: String
    var endAddress: String
    var destinationName: String
    var startCoordinate: CLLocationCoordinate2D
    var endCoordinate: CLLocationCoordinate2D
    var trackedDistanceMeters: Double
    var routeDistanceMeters: Double

    /// Miles that count: ONLY the miles actually driven, measured by GPS —
    /// wrong turns and detours included. The pre-calculated route distance
    /// is kept on the trip for reference but is never counted (Ty's rule,
    /// 2026-11-03).
    var loggedDistanceMeters: Double {
        trackedDistanceMeters
    }
    var loggedMiles: Double { loggedDistanceMeters / 1609.344 }
    var duration: TimeInterval { endDate.timeIntervalSince(startDate) }

    func makeTrip(category: TripCategory) -> Trip {
        Trip(startDate: startDate,
             endDate: endDate,
             startAddress: startAddress,
             endAddress: endAddress,
             destinationName: destinationName,
             startCoordinate: startCoordinate,
             endCoordinate: endCoordinate,
             distanceMeters: loggedDistanceMeters,
             trackedDistanceMeters: trackedDistanceMeters,
             routeDistanceMeters: routeDistanceMeters,
             category: category)
    }
}
