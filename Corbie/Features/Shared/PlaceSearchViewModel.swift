import Foundation
import MapKit
import Observation

final class PlaceCompleterBridge: NSObject, MKLocalSearchCompleterDelegate {
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
final class PlaceSearchViewModel {
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            updateCompleter()
        }
    }

    private(set) var suggestions: [MKLocalSearchCompletion] = []
    private(set) var isResolving = false

    @ObservationIgnored private let completer = MKLocalSearchCompleter()
    @ObservationIgnored private let bridge = PlaceCompleterBridge()

    init() {
        completer.resultTypes = [.pointOfInterest, .address]
        bridge.onResults = { [weak self] results in
            Task { @MainActor in
                self?.suggestions = results
            }
        }
        completer.delegate = bridge
    }

    var hasQuery: Bool { trimmedQuery.isEmpty == false }

    func resolve(_ suggestion: MKLocalSearchCompletion) async -> MapPlace? {
        isResolving = true
        defer { isResolving = false }
        let request = MKLocalSearch.Request(completion: suggestion)
        guard let response = try? await MKLocalSearch(request: request).start(),
              let item = response.mapItems.first else {
            return nil
        }
        let placemark = item.placemark
        return MapPlace(
            name: item.name ?? suggestion.title,
            address: placemark.title ?? blankToNil(suggestion.subtitle),
            latitude: placemark.coordinate.latitude,
            longitude: placemark.coordinate.longitude
        )
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func updateCompleter() {
        guard trimmedQuery.isEmpty == false else {
            suggestions = []
            completer.cancel()
            return
        }
        completer.queryFragment = trimmedQuery
    }

    private func blankToNil(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
