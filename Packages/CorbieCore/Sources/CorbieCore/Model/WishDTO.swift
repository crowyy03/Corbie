import Foundation

public struct WishDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var spaceId: UUID?
    public var ownerMemberId: UUID?
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
    public var isFulfilled: Bool
    public var fulfilledAt: Date?
    public var needsParse: Bool
    public var createdAt: Date?

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        ownerMemberId: UUID? = nil,
        addedByMemberId: UUID? = nil,
        title: String = "",
        url: String? = nil,
        imageURL: String? = nil,
        localImage: Data? = nil,
        price: Double? = nil,
        currency: String? = nil,
        priority: WishPriority = .want,
        note: String? = nil,
        source: WishSource = .manual,
        isFulfilled: Bool = false,
        fulfilledAt: Date? = nil,
        needsParse: Bool = false,
        createdAt: Date? = nil
    ) {
        self.id = id
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
        self.isFulfilled = isFulfilled
        self.fulfilledAt = fulfilledAt
        self.needsParse = needsParse
        self.createdAt = createdAt
    }

    public init(_ wish: Wish) {
        self.init(
            id: wish.id ?? UUID(),
            spaceId: wish.space?.id,
            ownerMemberId: wish.ownerMemberId,
            addedByMemberId: wish.addedByMemberId,
            title: wish.title ?? "",
            url: wish.url,
            imageURL: wish.imageURL,
            localImage: wish.localImage,
            price: wish.price?.doubleValue,
            currency: wish.currency,
            priority: wish.priority,
            note: wish.note,
            source: wish.source,
            isFulfilled: wish.isFulfilled,
            fulfilledAt: wish.fulfilledAt,
            needsParse: wish.needsParse,
            createdAt: wish.createdAt
        )
    }
}
