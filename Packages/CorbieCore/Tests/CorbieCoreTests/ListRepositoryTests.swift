import Foundation
import Testing
@testable import CorbieCore

@Suite struct ListRepositoryTests {
    @Test func tickingAnItemRecordsWhoDidIt() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.lists
        let list = try await repository.create(
            ChecklistDraft(spaceId: world.space.id, title: "Shopping", template: .shopping)
        )
        let item = try await repository.addItem(
            listId: list.id,
            draft: ListItemDraft(title: "Milk", addedByMemberId: world.me.id)
        )
        let at = Date(timeIntervalSince1970: 1_757_000_000)
        let checked = try await repository.toggleItem(itemId: item.id, memberId: world.partner.id, at: at)
        #expect(checked.isChecked)
        #expect(checked.checkedByMemberId == world.partner.id)
        #expect(checked.checkedAt == at)

        let unchecked = try await repository.toggleItem(itemId: item.id, memberId: world.partner.id, at: at)
        #expect(unchecked.isChecked == false)
        #expect(unchecked.checkedByMemberId == nil)
        #expect(unchecked.checkedAt == nil)
    }

    @Test func authorOnlyListsRejectThePartner() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.lists
        let list = try await repository.create(
            ChecklistDraft(spaceId: world.space.id, title: "My picks", anyoneCanCheck: false)
        )
        let item = try await repository.addItem(
            listId: list.id,
            draft: ListItemDraft(title: "Dune", addedByMemberId: world.me.id)
        )
        await #expect(throws: CorbieError.invalidInput("only the author can tick items in this list")) {
            _ = try await repository.toggleItem(itemId: item.id, memberId: world.partner.id)
        }
        let mine = try await repository.toggleItem(itemId: item.id, memberId: world.me.id)
        #expect(mine.isChecked)
    }

    @Test func reorderRewritesSortIndexes() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.lists
        let list = try await repository.create(ChecklistDraft(spaceId: world.space.id, title: "Cities"))
        let lisbon = try await repository.addItem(listId: list.id, draft: ListItemDraft(title: "Lisbon"))
        let porto = try await repository.addItem(listId: list.id, draft: ListItemDraft(title: "Porto"))
        let faro = try await repository.addItem(listId: list.id, draft: ListItemDraft(title: "Faro"))
        let initialOrder: [Int] = [lisbon.sortIndex, porto.sortIndex, faro.sortIndex]
        #expect(initialOrder == [0, 1, 2])

        let reordered = try await repository.reorder(listId: list.id, orderedItemIds: [faro.id, lisbon.id, porto.id])
        #expect(reordered.map(\.title) == ["Faro", "Lisbon", "Porto"])
        let newOrder: [Int] = reordered.map(\.sortIndex)
        #expect(newOrder == [0, 1, 2])
    }

    @Test func clearDoneRemovesOnlyTickedItems() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.lists
        let list = try await repository.create(ChecklistDraft(spaceId: world.space.id, title: "Shopping"))
        let milk = try await repository.addItem(listId: list.id, draft: ListItemDraft(title: "Milk"))
        _ = try await repository.addItem(listId: list.id, draft: ListItemDraft(title: "Bread"))
        _ = try await repository.toggleItem(itemId: milk.id, memberId: world.me.id)

        let remaining = try await repository.clearDone(listId: list.id)
        #expect(remaining.map(\.title) == ["Bread"])
        #expect(try await repository.items(listId: list.id).count == 1)
    }

    @Test func pinnedShoppingListIsCreatedOnce() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.lists
        let first = try await repository.pinnedShoppingList(spaceId: world.space.id, createdByMemberId: world.me.id)
        let second = try await repository.pinnedShoppingList(spaceId: world.space.id, createdByMemberId: world.partner.id)
        #expect(first.id == second.id)
        #expect(first.isPinnedShopping)
        #expect(first.template == .shopping)
        #expect(try await repository.lists(spaceId: world.space.id).count == 1)
    }

    @Test func deletingAListRemovesItsItems() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.lists
        let list = try await repository.create(ChecklistDraft(spaceId: world.space.id, title: "Temporary"))
        _ = try await repository.addItem(listId: list.id, draft: ListItemDraft(title: "One"))
        try await repository.delete(id: list.id)
        #expect(try world.count("ListItem") == 0)
    }
}
