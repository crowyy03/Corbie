import Foundation

public struct SpaceDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var createdAt: Date?
    public var creatorMemberId: UUID?
    public var togetherSince: Date?
    public var weddingDate: Date?
    public var displayCurrency: String
    public var subscriptionStatus: SubscriptionStatus
    public var subscriptionExpiresAt: Date?
    public var subscriptionPayerMemberId: UUID?
    public var anchorTimeZone: String?
    public var questionSeed: Int64
    public var questionIndex: Int
    public var memberCount: Int

    public init(
        id: UUID,
        createdAt: Date? = nil,
        creatorMemberId: UUID? = nil,
        togetherSince: Date? = nil,
        weddingDate: Date? = nil,
        displayCurrency: String = "USD",
        subscriptionStatus: SubscriptionStatus = .none,
        subscriptionExpiresAt: Date? = nil,
        subscriptionPayerMemberId: UUID? = nil,
        anchorTimeZone: String? = nil,
        questionSeed: Int64 = 0,
        questionIndex: Int = 0,
        memberCount: Int = 0
    ) {
        self.id = id
        self.createdAt = createdAt
        self.creatorMemberId = creatorMemberId
        self.togetherSince = togetherSince
        self.weddingDate = weddingDate
        self.displayCurrency = displayCurrency
        self.subscriptionStatus = subscriptionStatus
        self.subscriptionExpiresAt = subscriptionExpiresAt
        self.subscriptionPayerMemberId = subscriptionPayerMemberId
        self.anchorTimeZone = anchorTimeZone
        self.questionSeed = questionSeed
        self.questionIndex = questionIndex
        self.memberCount = memberCount
    }

    public init(_ space: Space) {
        self.init(
            id: space.id ?? UUID(),
            createdAt: space.createdAt,
            creatorMemberId: space.creatorMemberId,
            togetherSince: space.togetherSince,
            weddingDate: space.weddingDate,
            displayCurrency: space.displayCurrency ?? "USD",
            subscriptionStatus: space.subscriptionStatus,
            subscriptionExpiresAt: space.subscriptionExpiresAt,
            subscriptionPayerMemberId: space.subscriptionPayerMemberId,
            anchorTimeZone: space.anchorTimeZone,
            questionSeed: space.questionSeed,
            questionIndex: Int(space.questionIndex),
            memberCount: space.members.count
        )
    }

    public var isPaired: Bool { memberCount >= 2 }

    public var anchorCalendarTimeZone: TimeZone {
        guard let anchorTimeZone, let zone = TimeZone(identifier: anchorTimeZone) else { return .current }
        return zone
    }
}
