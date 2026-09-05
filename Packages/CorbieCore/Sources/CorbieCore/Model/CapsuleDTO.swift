import Foundation

public struct CapsuleDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var spaceId: UUID?
    public var authorMemberId: UUID?
    public var recipientMemberId: UUID?
    public var title: String
    public var body: String
    public var opensAt: Date?
    public var openedAt: Date?
    public var openedByMemberIds: [UUID]
    public var createdAt: Date?

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        authorMemberId: UUID? = nil,
        recipientMemberId: UUID? = nil,
        title: String = "",
        body: String = "",
        opensAt: Date? = nil,
        openedAt: Date? = nil,
        openedByMemberIds: [UUID] = [],
        createdAt: Date? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.authorMemberId = authorMemberId
        self.recipientMemberId = recipientMemberId
        self.title = title
        self.body = body
        self.opensAt = opensAt
        self.openedAt = openedAt
        self.openedByMemberIds = openedByMemberIds
        self.createdAt = createdAt
    }

    public init(_ capsule: CapsuleItem) {
        self.init(
            id: capsule.id ?? UUID(),
            spaceId: capsule.space?.id,
            authorMemberId: capsule.authorMemberId,
            recipientMemberId: capsule.recipientMemberId,
            title: capsule.title ?? "",
            body: capsule.body ?? "",
            opensAt: capsule.opensAt,
            openedAt: capsule.openedAt,
            openedByMemberIds: capsule.openedByMemberIds,
            createdAt: capsule.createdAt
        )
    }

    public func isUnlocked(at date: Date = Date()) -> Bool {
        guard let opensAt else { return false }
        return opensAt <= date
    }

    public func isEditable(at date: Date = Date()) -> Bool {
        openedAt == nil && isUnlocked(at: date) == false
    }

    public var isReadByBoth: Bool { openedByMemberIds.count >= 2 }
}
