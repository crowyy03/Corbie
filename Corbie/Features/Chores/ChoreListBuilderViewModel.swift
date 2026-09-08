import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class ChoreListBuilderViewModel {
    private(set) var choreSet: ChoreSetDTO
    private(set) var isWorking = false
    var drafts: [String: String] = [:]

    @ObservationIgnored var onError: ((any Error) -> Void)?
    @ObservationIgnored var onChanged: ((ChoreSetDTO) -> Void)?

    @ObservationIgnored private let repository: any ChoreRepository
    @ObservationIgnored private let catalog: ChoreCatalog
    @ObservationIgnored private let memberId: UUID?
    @ObservationIgnored private let analytics: any AnalyticsRecording
    @ObservationIgnored private let locale: Locale

    init(
        set: ChoreSetDTO,
        repository: any ChoreRepository,
        catalog: ChoreCatalog = .bundled,
        memberId: UUID?,
        analytics: any AnalyticsRecording,
        locale: Locale = .current
    ) {
        choreSet = set
        self.repository = repository
        self.catalog = catalog
        self.memberId = memberId
        self.analytics = analytics
        self.locale = locale
    }

    var groups: [ChoreGroup] { catalog.groups }

    var customItems: [ChoreItemDTO] { choreSet.items.filter(\.isCustom) }

    var includedCount: Int { choreSet.includedItems.count }

    var canContinue: Bool { choreSet.canStartRating && isWorking == false }

    var missingCount: Int { max(0, ChoreSetDTO.minimumIncludedItems - includedCount) }

    func catalogItems(in group: ChoreGroup) -> [ChoreCatalogItem] { catalog.items(in: group) }

    func title(of item: ChoreCatalogItem) -> String { item.text(for: locale) }

    func isIncluded(_ item: ChoreCatalogItem) -> Bool {
        choreSet.items.first { $0.catalogId == item.id }?.isIncluded ?? false
    }

    func frequency(of item: ChoreCatalogItem) -> ChoreFrequency {
        choreSet.items.first { $0.catalogId == item.id }?.frequency ?? item.frequency
    }

    func isInTheList(_ item: ChoreCatalogItem) -> Bool {
        choreSet.items.contains { $0.catalogId == item.id }
    }

    func toggle(_ item: ChoreCatalogItem) async {
        await change {
            guard let existing = self.choreSet.items.first(where: { $0.catalogId == item.id }) else {
                return try await self.repository.addItem(
                    setId: self.choreSet.id,
                    draft: ChoreItemDraft(catalogId: item.id, title: "", addedByMemberId: self.memberId)
                )
            }
            return try await self.repository.setIncluded(itemId: existing.id, isIncluded: existing.isIncluded == false)
        }
    }

    func toggle(_ item: ChoreItemDTO) async {
        await change {
            try await self.repository.setIncluded(itemId: item.id, isIncluded: item.isIncluded == false)
        }
    }

    func setFrequency(_ frequency: ChoreFrequency, of item: ChoreCatalogItem) async {
        guard let existing = choreSet.items.first(where: { $0.catalogId == item.id }) else { return }
        await setFrequency(frequency, of: existing)
    }

    func setFrequency(_ frequency: ChoreFrequency, of item: ChoreItemDTO) async {
        await change {
            try await self.repository.setFrequency(itemId: item.id, frequency: frequency)
        }
    }

    func remove(_ item: ChoreItemDTO) async {
        await change {
            try await self.repository.removeItem(itemId: item.id)
        }
    }

    func addCustom(in group: ChoreGroup) async {
        let title = (drafts[group.rawValue] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else { return }
        let added = await change {
            try await self.repository.addItem(
                setId: self.choreSet.id,
                draft: ChoreItemDraft(title: title, addedByMemberId: self.memberId)
            )
        }
        guard added else { return }
        drafts[group.rawValue] = ""
    }

    func startRating() async {
        guard canContinue else { return }
        let itemCount = choreSet.includedItems.count
        let customCount = choreSet.includedItems.filter(\.isCustom).count
        let started = await change {
            try await self.repository.startRating(setId: self.choreSet.id)
        }
        guard started else { return }
        analytics.record(.choreListBuilt(itemCount: itemCount, customCount: customCount))
    }

    @discardableResult
    private func change(_ write: @escaping () async throws -> ChoreSetDTO) async -> Bool {
        guard isWorking == false else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            choreSet = try await write()
            onChanged?(choreSet)
            return true
        } catch {
            onError?(error)
            return false
        }
    }
}
