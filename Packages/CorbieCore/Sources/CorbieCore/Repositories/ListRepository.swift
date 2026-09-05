import Foundation

public struct ChecklistDraft: Sendable, Equatable {
    public var spaceId: UUID
    public var title: String
    public var subtitle: String?
    public var template: ListTemplate
    public var anyoneCanCheck: Bool
    public var isPinnedShopping: Bool
    public var createdByMemberId: UUID?

    public init(
        spaceId: UUID,
        title: String,
        subtitle: String? = nil,
        template: ListTemplate = .empty,
        anyoneCanCheck: Bool = true,
        isPinnedShopping: Bool = false,
        createdByMemberId: UUID? = nil
    ) {
        self.spaceId = spaceId
        self.title = title
        self.subtitle = subtitle
        self.template = template
        self.anyoneCanCheck = anyoneCanCheck
        self.isPinnedShopping = isPinnedShopping
        self.createdByMemberId = createdByMemberId
    }
}

public struct ListItemDraft: Sendable, Equatable {
    public var title: String
    public var note: String?
    public var placeName: String?
    public var address: String?
    public var latitude: Double?
    public var longitude: Double?
    public var addedByMemberId: UUID?

    public init(
        title: String,
        note: String? = nil,
        placeName: String? = nil,
        address: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        addedByMemberId: UUID? = nil
    ) {
        self.title = title
        self.note = note
        self.placeName = placeName
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.addedByMemberId = addedByMemberId
    }
}

public protocol ListRepository: Sendable {
    func create(_ draft: ChecklistDraft) async throws -> ChecklistListDTO
    func update(_ list: ChecklistListDTO) async throws -> ChecklistListDTO
    func list(id: UUID) async throws -> ChecklistListDTO?
    func lists(spaceId: UUID) async throws -> [ChecklistListDTO]
    func delete(id: UUID) async throws
    func pinnedShoppingList(spaceId: UUID, title: String, createdByMemberId: UUID?) async throws -> ChecklistListDTO
    func addItem(listId: UUID, draft: ListItemDraft) async throws -> ListItemDTO
    func updateItem(_ item: ListItemDTO) async throws -> ListItemDTO
    func toggleItem(itemId: UUID, memberId: UUID?, at date: Date) async throws -> ListItemDTO
    func items(listId: UUID) async throws -> [ListItemDTO]
    func reorder(listId: UUID, orderedItemIds: [UUID]) async throws -> [ListItemDTO]
    func deleteItem(id: UUID) async throws
    func clearDone(listId: UUID) async throws -> [ListItemDTO]
}

extension ListRepository {
    public func toggleItem(itemId: UUID, memberId: UUID?) async throws -> ListItemDTO {
        try await toggleItem(itemId: itemId, memberId: memberId, at: Date())
    }

    public func pinnedShoppingList(spaceId: UUID, title: String) async throws -> ChecklistListDTO {
        try await pinnedShoppingList(spaceId: spaceId, title: title, createdByMemberId: nil)
    }
}
