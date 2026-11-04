import Foundation
import MapKit

/// Address / place search backed by MapKit (no API key needed):
/// live autocomplete suggestions plus one-shot free-text search.
final class PlaceSearch: NSObject, ObservableObject {
    @Published var suggestions: [MKLocalSearchCompletion] = []
    @Published var isSearching = false

    private let completer: MKLocalSearchCompleter

    override init() {
        completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateQuery(_ query: String) {
        completer.queryFragment = query
    }

    /// Resolves a tapped autocomplete suggestion into a full map item.
    func resolve(_ completion: MKLocalSearchCompletion,
                 completionHandler: @escaping (MKMapItem?) -> Void) {
        let search = MKLocalSearch(request: MKLocalSearch.Request(completion: completion))
        isSearching = true
        search.start { [weak self] response, _ in
            DispatchQueue.main.async {
                self?.isSearching = false
                completionHandler(response?.mapItems.first)
            }
        }
    }

    /// Free-text search used when the typed text is submitted directly.
    func search(query: String,
                near coordinate: CLLocationCoordinate2D?,
                completionHandler: @escaping (MKMapItem?) -> Void) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        if let coordinate = coordinate {
            request.region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5))
        }
        let search = MKLocalSearch(request: request)
        isSearching = true
        search.start { [weak self] response, _ in
            DispatchQueue.main.async {
                self?.isSearching = false
                completionHandler(response?.mapItems.first)
            }
        }
    }
}

extension PlaceSearch: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.suggestions = completer.results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.suggestions = []
        }
    }
}
