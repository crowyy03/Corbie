import CorbieCore
import Observation
import SwiftUI

@MainActor
@Observable
final class ListDetailViewModel {
    enum Mode: String, CaseIterable, Hashable {
        case list
        case map
    }

    var mode: Mode = .list
    var draftTitle = ""
    var editingItem: ListItemDTO?
    var isEditingList = false
    var isConfirmingDelete = false
    private(set) var list: ChecklistListDTO?
    private(set) var items: [ListItemDTO] = []
    private(set) var isLoaded = false

    @ObservationIgnored private let listId: UUID
    @ObservationIgnored private var environment: AppEnvironment?

    init(listId: UUID) {
        self.listId = listId
    }

    var placedItems: [ListItemDTO] {
        items.filter(\.hasPlace)
    }

    var showsClearDone: Bool {
        list?.isPinnedShopping == true && items.contains(where: \.isChecked)
    }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
    }

    func load() async {
        guard let environment else { return }
        do {
            list = try await environment.repositories.lists.list(id: listId)
            items = try await environment.repositories.lists.items(listId: listId)
        } catch {
            environment.report(error)
        }
        isLoaded = true
    }

    func toggleMode() {
        mode = mode == .list ? .map : .list
        guard mode == .map else { return }
        environment?.analytics.record(.listMapOpened)
    }

    func addDraftItem() async {
        let title = draftTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false, let environment else { return }
        guard environment.premiumGate.require(.create) else { return }
        do {
            _ = try await environment.repositories.lists.addItem(
                listId: listId,
                draft: ListItemDraft(title: title, addedByMemberId: environment.currentMember?.id)
            )
            draftTitle = ""
        } catch {
            environment.report(error)
        }
        await load()
    }

    func toggle(_ item: ListItemDTO) async {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        do {
            let updated = try await environment.repositories.lists.toggleItem(
                itemId: item.id,
                memberId: environment.currentMember?.id
            )
            if updated.isChecked {
                environment.analytics.record(.listItemChecked)
            }
        } catch {
            environment.report(error)
        }
        await load()
    }

    func deleteItems(at offsets: IndexSet) async {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        let doomed = offsets.map { items[$0] }
        do {
            for item in doomed {
                try await environment.repositories.lists.deleteItem(id: item.id)
            }
        } catch {
            environment.report(error)
        }
        await load()
    }

    func moveItems(from offsets: IndexSet, to destination: Int) async {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        var ordered = items
        ordered.move(fromOffsets: offsets, toOffset: destination)
        items = ordered
        do {
            _ = try await environment.repositories.lists.reorder(
                listId: listId,
                orderedItemIds: ordered.map(\.id)
            )
        } catch {
            environment.report(error)
        }
        await load()
    }

    func clearDone() async {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        do {
            _ = try await environment.repositories.lists.clearDone(listId: listId)
        } catch {
            environment.report(error)
        }
        await load()
    }

    func startEditing(_ item: ListItemDTO) {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        editingItem = item
    }

    func startEditingList() {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        isEditingList = true
    }

    func startDeletingList() {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        isConfirmingDelete = true
    }

    func deleteList() async -> Bool {
        guard let environment else { return false }
        do {
            try await environment.repositories.lists.delete(id: listId)
            return true
        } catch {
            environment.report(error)
            return false
        }
    }
}
