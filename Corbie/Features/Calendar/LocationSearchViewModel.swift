import CorbieCore
import Foundation
import MapKit
import Observation

struct CalendarPlace: Equatable {
    var name: String
    var address: String?
    var latitude: Double
    var longitude: Double

    init(name: String, address: String? = nil, latitude: Double, longitude: Double) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
    }

    init?(event: EventDTO) {
        guard let name = event.locationName, let latitude = event.latitude, let longitude = event.longitude else {
            return nil
        }
        self.init(name: name, address: event.address, latitude: latitude, longitude: longitude)
    }
}

final class LocationCompleterBridge: NSObject, MKLocalSearchCompleterDelegate {
    var onResults: (([MKLocalSearchCompletion]) -> Void)?

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        onResults?(completer.results)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        onResults?([])
    }
}

@MainActor
@Observable
final class LocationSearchViewModel {
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            updateCompleter()
        }
    }

    private(set) var suggestions: [MKLocalSearchCompletion] = []
    private(set) var isResolving = false

    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    @ObservationIgnored private let bridge = LocationCompleterBridge()

    init() {
        completer.resultTypes = [.pointOfInterest, .address]
        bridge.onResults = { [weak self] results in
            Task { @MainActor in
                self?.suggestions = results
            }
        }
        completer.delegate = bridge
    }

    func resolve(_ suggestion: MKLocalSearchCompletion) async -> CalendarPlace? {
        isResolving = true
        defer { isResolving = false }
        let request = MKLocalSearch.Request(completion: suggestion)
        guard let response = try? await MKLocalSearch(request: request).start(),
              let item = response.mapItems.first else {
            return nil
        }
        let placemark = item.placemark
        return CalendarPlace(
            name: item.name ?? suggestion.title,
            address: placemark.title ?? blankToNil(suggestion.subtitle),
            latitude: placemark.coordinate.latitude,
            longitude: placemark.coordinate.longitude
        )
    }

    private func updateCompleter() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            suggestions = []
            completer.cancel()
            return
        }
        completer.queryFragment = trimmed
    }

    private func blankToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
