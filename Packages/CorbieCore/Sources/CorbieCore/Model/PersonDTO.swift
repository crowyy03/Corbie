import Foundation

public struct PersonDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var spaceId: UUID?
    public var name: String
    public var relation: String?
    public var birthdayMonth: Int?
    public var birthdayDay: Int?
    public var ownerMemberId: UUID?
    public var note: String?
    public var giftIdeaCount: Int
    public var hasPickedGift: Bool

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        name: String = "",
        relation: String? = nil,
        birthdayMonth: Int? = nil,
        birthdayDay: Int? = nil,
        ownerMemberId: UUID? = nil,
        note: String? = nil,
        giftIdeaCount: Int = 0,
        hasPickedGift: Bool = false
    ) {
        self.id = id
        self.spaceId = spaceId
        self.name = name
        self.relation = relation
        self.birthdayMonth = birthdayMonth
        self.birthdayDay = birthdayDay
        self.ownerMemberId = ownerMemberId
        self.note = note
        self.giftIdeaCount = giftIdeaCount
        self.hasPickedGift = hasPickedGift
    }

    public init(_ person: Person) {
        let ideas = person.giftIdeas
        self.init(
            id: person.id ?? UUID(),
            spaceId: person.space?.id,
            name: person.name ?? "",
            relation: person.relation,
            birthdayMonth: person.birthdayMonth?.intValue,
            birthdayDay: person.birthdayDay?.intValue,
            ownerMemberId: person.ownerMemberId,
            note: person.note,
            giftIdeaCount: ideas.count,
            hasPickedGift: ideas.contains(where: \.isDone)
        )
    }

    public var hasBirthday: Bool { birthdayMonth != nil && birthdayDay != nil }
}
