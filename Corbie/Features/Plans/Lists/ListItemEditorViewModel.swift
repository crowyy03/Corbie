import CorbieCore
import Observation
import SwiftUI

@MainActor
@Observable
final class ListItemEditorViewModel {
    var title: String
    var note: String
    var isSearchingPlace = false
    private(set) var placeName: String?
    private(set) var address: String?
    private(set) var latitude: Double?
    private(set) var longitude: Double?
    private(set) var isSaving = false

    @ObservationIgnored private let item: ListItemDTO
    @ObservationIgnored private var environment: AppEnvironment?

    init(item: ListItemDTO) {
        self.item = item
        title = item.title
        note = item.note ?? ""
        placeName = item.placeName
        address = item.address
        latitude = item.latitude
        longitude = item.longitude
    }

    var hasPlace: Bool { latitude != nil && longitude != nil }

    var canSave: Bool {
        isSaving == false && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
    }

    func startPlaceSearch() {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        isSearchingPlace = true
    }

    func apply(_ place: PlaceResult) {
        placeName = place.name
        address = place.address
        latitude = place.latitude
        longitude = place.longitude
    }

    func removePlace() {
        placeName = nil
        address = nil
        latitude = nil
        longitude = nil
    }

    func save() async -> Bool {
        guard let environment, environment.premiumGate.require(.edit) else { return false }
        isSaving = true
        defer { isSaving = false }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var updated = item
        updated.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.note = trimmedNote.isEmpty ? nil : trimmedNote
        updated.placeName = placeName
        updated.address = address
        updated.latitude = latitude
        updated.longitude = longitude
        do {
            _ = try await environment.repositories.lists.updateItem(updated)
            return true
        } catch {
            environment.report(error)
            return false
        }
    }
}
