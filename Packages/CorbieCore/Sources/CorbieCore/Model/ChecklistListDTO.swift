import Foundation

public struct ChecklistListDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var spaceId: UUID?
    public var title: String
    public var subtitle: String?
    public var template: ListTemplate
    public var anyoneCanCheck: Bool
    public var isPinnedShopping: Bool
    public var createdByMemberId: UUID?
    public var createdAt: Date?
    public var itemCount: Int
    public var checkedCount: Int

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        title: String = "",
        subtitle: String? = nil,
        template: ListTemplate = .empty,
        anyoneCanCheck: Bool = true,
        isPinnedShopping: Bool = false,
        createdByMemberId: UUID? = nil,
        createdAt: Date? = nil,
        itemCount: Int = 0,
        checkedCount: Int = 0
    ) {
        self.id = id
        self.spaceId = spaceId
        self.title = title
        self.subtitle = subtitle
        self.template = template
        self.anyoneCanCheck = anyoneCanCheck
        self.isPinnedShopping = isPinnedShopping
        self.createdByMemberId = createdByMemberId
        self.createdAt = createdAt
        self.itemCount = itemCount
        self.checkedCount = checkedCount
    }

    public init(_ list: ChecklistList) {
        let items = list.items
        self.init(
            id: list.id ?? UUID(),
            spaceId: list.space?.id,
            title: list.title ?? "",
            subtitle: list.subtitle,
            template: list.template,
            anyoneCanCheck: list.anyoneCanCheck,
            isPinnedShopping: list.isPinnedShopping,
            createdByMemberId: list.createdByMemberId,
            createdAt: list.createdAt,
            itemCount: items.count,
            checkedCount: items.filter(\.isChecked).count
        )
    }
}
