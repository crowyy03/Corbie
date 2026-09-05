import CorbieCore
import MapKit
import Observation
import SwiftUI

struct PlaceResult: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let address: String?
    let latitude: Double
    let longitude: Double
}

@MainActor
@Observable
final class PlaceSearchViewModel {
    var query = ""
    private(set) var results: [PlaceResult] = []
    private(set) var isSearching = false
    private(set) var didSearch = false

    @ObservationIgnored private var environment: AppEnvironment?

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
    }

    func search() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        isSearching = true
        defer {
            isSearching = false
            didSearch = true
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        do {
            let response = try await MKLocalSearch(request: request).start()
            results = response.mapItems.compactMap(PlaceSearchViewModel.result(for:))
        } catch {
            results = []
            environment?.report(CorbieError.network(error.localizedDescription))
        }
    }

    private static func result(for item: MKMapItem) -> PlaceResult? {
        let coordinate = item.placemark.coordinate
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        let name = item.name ?? item.placemark.title ?? ""
        guard name.isEmpty == false else { return nil }
        return PlaceResult(
            id: "\(coordinate.latitude),\(coordinate.longitude),\(name)",
            name: name,
            address: item.placemark.title,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
    }
}
