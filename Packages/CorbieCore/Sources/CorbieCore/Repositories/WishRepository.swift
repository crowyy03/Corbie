import Foundation

public struct WishDraft: Sendable, Equatable {
    public var spaceId: UUID
    public var ownerMemberId: UUID
    public var addedByMemberId: UUID?
    public var title: String
    public var url: String?
    public var imageURL: String?
    public var localImage: Data?
    public var price: Double?
    public var currency: String?
    public var priority: WishPriority
    public var note: String?
    public var source: WishSource
    public var needsParse: Bool

    public init(
        spaceId: UUID,
        ownerMemberId: UUID,
        addedByMemberId: UUID? = nil,
        title: String,
        url: String? = nil,
        imageURL: String? = nil,
        localImage: Data? = nil,
        price: Double? = nil,
        currency: String? = nil,
        priority: WishPriority = .want,
        note: String? = nil,
        source: WishSource = .manual,
        needsParse: Bool = false
    ) {
        self.spaceId = spaceId
        self.ownerMemberId = ownerMemberId
        self.addedByMemberId = addedByMemberId
        self.title = title
        self.url = url
        self.imageURL = imageURL
        self.localImage = localImage
        self.price = price
        self.currency = currency
        self.priority = priority
        self.note = note
        self.source = source
        self.needsParse = needsParse
    }
}

public enum WishOwnerFilter: Sendable, Equatable {
    case any
    case member(UUID)
}

public struct WishQuery: Sendable, Equatable {
    public var spaceId: UUID
    public var owner: WishOwnerFilter
    public var fulfilled: Bool?

    public init(spaceId: UUID, owner: WishOwnerFilter = .any, fulfilled: Bool? = false) {
        self.spaceId = spaceId
        self.owner = owner
        self.fulfilled = fulfilled
    }
}

public protocol WishRepository: Sendable {
    func create(_ draft: WishDraft) async throws -> WishDTO
    func update(_ wish: WishDTO) async throws -> WishDTO
    func fulfil(wishId: UUID, at date: Date) async throws -> WishDTO
    func wish(id: UUID) async throws -> WishDTO?
    func wishes(_ query: WishQuery) async throws -> [WishDTO]
    func pendingParse(spaceId: UUID) async throws -> [WishDTO]
    func delete(id: UUID) async throws
}

extension WishRepository {
    public func fulfil(wishId: UUID) async throws -> WishDTO {
        try await fulfil(wishId: wishId, at: Date())
    }
}
