import CoreData
import Foundation

public struct CoreDataListRepository: ListRepository {
    private let access: CoreDataAccess

    public init(stack: CoreDataStack) {
        access = CoreDataAccess(stack: stack)
    }

    public func create(_ draft: ChecklistDraft) async throws -> ChecklistListDTO {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            throw CorbieError.invalidInput("list title is empty")
        }
        return try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: draft.spaceId, in: context)
            let list = ChecklistList(context: context)
            context.assign(list, toStoreOf: space)
            list.space = space
            list.title = title
            list.subtitle = draft.subtitle
            list.template = draft.template
            list.anyoneCanCheck = draft.anyoneCanCheck
            list.isPinnedShopping = draft.isPinnedShopping
            list.createdByMemberId = draft.createdByMemberId
            return ChecklistListDTO(list)
        }
    }

    public func update(_ edited: ChecklistListDTO, from original: ChecklistListDTO) async throws -> ChecklistListDTO {
        let changes = try FieldChanges(edited, from: original)
        let title = edited.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if changes.changed(\.title), title.isEmpty {
            throw CorbieError.invalidInput("list title is empty")
        }
        return try await access.write { context in
            let list: ChecklistList = try ManagedFetch.require(ChecklistList.entityName, id: edited.id, in: context)
            changes.write(\.title) { _ in list.title = title }
            changes.write(\.subtitle) { list.subtitle = $0 }
            changes.write(\.template) { list.template = $0 }
            changes.write(\.anyoneCanCheck) { list.anyoneCanCheck = $0 }
            return ChecklistListDTO(list)
        }
    }

    public func list(id: UUID) async throws -> ChecklistListDTO? {
        try await access.read { context in
            let list: ChecklistList? = try ManagedFetch.first(ChecklistList.entityName, id: id, in: context)
            return list.map(ChecklistListDTO.init)
        }
    }

    public func lists(spaceId: UUID) async throws -> [ChecklistListDTO] {
        try await access.read { context in
            let lists: [ChecklistList] = try ManagedFetch.all(
                ChecklistList.entityName,
                predicate: ManagedFetch.spaceRelation(spaceId),
                sort: [
                    NSSortDescriptor(key: "isPinnedShopping", ascending: false),
                    NSSortDescriptor(key: "createdAt", ascending: false)
                ],
                in: context
            )
            return lists.map(ChecklistListDTO.init)
        }
    }

    public func delete(id: UUID) async throws {
        try await access.write { context in
            let list: ChecklistList? = try ManagedFetch.first(ChecklistList.entityName, id: id, in: context)
            guard let list else { return }
            context.delete(list)
        }
    }

    public func pinnedShoppingList(
        spaceId: UUID,
        title: String,
        createdByMemberId: UUID?
    ) async throws -> ChecklistListDTO {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else {
            throw CorbieError.invalidInput("list title is empty")
        }
        return try await access.write { context in
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                ManagedFetch.spaceRelation(spaceId),
                NSPredicate(format: "isPinnedShopping == YES")
            ])
            let existing: [ChecklistList] = try ManagedFetch.all(
                ChecklistList.entityName,
                predicate: predicate,
                sort: [NSSortDescriptor(key: "createdAt", ascending: true)],
                in: context
            )
            if let pinned = CoreDataListRepository.keepOnePinned(existing, in: context) {
                return ChecklistListDTO(pinned)
            }
            let space: Space = try ManagedFetch.require(Space.entityName, id: spaceId, in: context)
            let list = ChecklistList(context: context)
            context.assign(list, toStoreOf: space)
            list.space = space
            list.title = name
            list.template = .shopping
            list.isPinnedShopping = true
            list.anyoneCanCheck = true
            list.createdByMemberId = createdByMemberId
            return ChecklistListDTO(list)
        }
    }

    public func addItem(listId: UUID, draft: ListItemDraft) async throws -> ListItemDTO {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            throw CorbieError.invalidInput("list item title is empty")
        }
        return try await access.write { context in
            let list: ChecklistList = try ManagedFetch.require(ChecklistList.entityName, id: listId, in: context)
            let nextIndex = (list.items.map(\.sortIndex).max() ?? -1) + 1
            let item = ListItem(context: context)
            context.assign(item, toStoreOf: list)
            item.list = list
            item.title = title
            item.note = draft.note
            item.placeName = draft.placeName
            item.address = draft.address
            item.latitude = draft.latitude.map(NSNumber.init(value:))
            item.longitude = draft.longitude.map(NSNumber.init(value:))
            item.addedByMemberId = draft.addedByMemberId
            item.sortIndex = nextIndex
            return ListItemDTO(item)
        }
    }

    public func updateItem(_ edited: ListItemDTO, from original: ListItemDTO) async throws -> ListItemDTO {
        let changes = try FieldChanges(edited, from: original)
        let title = edited.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if changes.changed(\.title), title.isEmpty {
            throw CorbieError.invalidInput("list item title is empty")
        }
        let movesPlace = changes.changed(\.placeName) || changes.changed(\.address)
            || changes.changed(\.latitude) || changes.changed(\.longitude)
        return try await access.write { context in
            let item: ListItem = try ManagedFetch.require(ListItem.entityName, id: edited.id, in: context)
            changes.write(\.title) { _ in item.title = title }
            changes.write(\.note) { item.note = $0 }
            if movesPlace {
                item.placeName = edited.placeName
                item.address = edited.address
                item.latitude = edited.latitude.map(NSNumber.init(value:))
                item.longitude = edited.longitude.map(NSNumber.init(value:))
            }
            return ListItemDTO(item)
        }
    }

    public func toggleItem(itemId: UUID, memberId: UUID?, at date: Date) async throws -> ListItemDTO {
        try await access.write { context in
            let item: ListItem = try ManagedFetch.require(ListItem.entityName, id: itemId, in: context)
            try CoreDataListRepository.requireTickRight(on: item, memberId: memberId)
            CoreDataListRepository.setChecked(item, to: !item.isChecked, memberId: memberId, at: date)
            return ListItemDTO(item)
        }
    }

    public func setItemChecked(itemId: UUID, _ isChecked: Bool, memberId: UUID?, at date: Date) async throws -> ListItemDTO {
        try await access.write { context in
            let item: ListItem = try ManagedFetch.require(ListItem.entityName, id: itemId, in: context)
            guard item.isChecked != isChecked else { return ListItemDTO(item) }
            try CoreDataListRepository.requireTickRight(on: item, memberId: memberId)
            CoreDataListRepository.setChecked(item, to: isChecked, memberId: memberId, at: date)
            return ListItemDTO(item)
        }
    }

    private static func requireTickRight(on item: ListItem, memberId: UUID?) throws {
        guard item.list?.anyoneCanCheck == false else { return }
        let author = item.addedByMemberId ?? item.list?.createdByMemberId
        guard let memberId, let author, memberId == author else {
            throw CorbieError.invalidInput("only the author can tick items in this list")
        }
    }

    private static func setChecked(_ item: ListItem, to isChecked: Bool, memberId: UUID?, at date: Date) {
        item.isChecked = isChecked
        item.checkedByMemberId = isChecked ? memberId : nil
        item.checkedAt = isChecked ? date : nil
    }

    public func items(listId: UUID) async throws -> [ListItemDTO] {
        try await access.read { context in
            let items: [ListItem] = try ManagedFetch.all(
                ListItem.entityName,
                predicate: NSPredicate(format: "list.id == %@", listId as NSUUID),
                sort: [
                    NSSortDescriptor(key: "isChecked", ascending: true),
                    NSSortDescriptor(key: "sortIndex", ascending: true)
                ],
                in: context
            )
            return items.map(ListItemDTO.init)
        }
    }

    public func reorder(listId: UUID, orderedItemIds: [UUID]) async throws -> [ListItemDTO] {
        try await access.write { context in
            let items: [ListItem] = try ManagedFetch.all(
                ListItem.entityName,
                predicate: NSPredicate(format: "list.id == %@", listId as NSUUID),
                in: context
            )
            var byID: [UUID: ListItem] = [:]
            for item in items {
                if let id = item.id { byID[id] = item }
            }
            var index: Int32 = 0
            for id in orderedItemIds {
                guard let item = byID.removeValue(forKey: id) else { continue }
                item.sortIndex = index
                index += 1
            }
            for item in byID.values.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                item.sortIndex = index
                index += 1
            }
            return items
                .sorted { $0.sortIndex < $1.sortIndex }
                .map(ListItemDTO.init)
        }
    }

    public func deleteItem(id: UUID) async throws {
        try await access.write { context in
            guard let item: ListItem = try ManagedFetch.first(ListItem.entityName, id: id, in: context) else { return }
            context.delete(item)
        }
    }

    public func clearDone(listId: UUID) async throws -> [ListItemDTO] {
        try await access.write { context in
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "list.id == %@", listId as NSUUID),
                NSPredicate(format: "isChecked == YES")
            ])
            let done: [ListItem] = try ManagedFetch.all(ListItem.entityName, predicate: predicate, in: context)
            for item in done {
                context.delete(item)
            }
            let remaining: [ListItem] = try ManagedFetch.all(
                ListItem.entityName,
                predicate: NSPredicate(format: "list.id == %@", listId as NSUUID),
                sort: [NSSortDescriptor(key: "sortIndex", ascending: true)],
                in: context
            )
            return remaining.filter { $0.isDeleted == false }.map(ListItemDTO.init)
        }
    }

    private static func keepOnePinned(_ pinned: [ChecklistList], in context: NSManagedObjectContext) -> ChecklistList? {
        let ordered = pinned.sorted { lhs, rhs in
            let left = lhs.createdAt ?? .distantPast
            let right = rhs.createdAt ?? .distantPast
            if left != right { return left < right }
            return (lhs.id?.uuidString ?? "") < (rhs.id?.uuidString ?? "")
        }
        guard let kept = ordered.first else { return nil }
        for duplicate in ordered.dropFirst() {
            for item in duplicate.items {
                item.list = kept
            }
            context.delete(duplicate)
        }
        return kept
    }
}
