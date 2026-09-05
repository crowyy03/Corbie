import Foundation

public struct PersonDraft: Sendable, Equatable {
    public var spaceId: UUID
    public var name: String
    public var relation: String?
    public var birthdayMonth: Int?
    public var birthdayDay: Int?
    public var ownerMemberId: UUID?
    public var note: String?

    public init(
        spaceId: UUID,
        name: String,
        relation: String? = nil,
        birthdayMonth: Int? = nil,
        birthdayDay: Int? = nil,
        ownerMemberId: UUID? = nil,
        note: String? = nil
    ) {
        self.spaceId = spaceId
        self.name = name
        self.relation = relation
        self.birthdayMonth = birthdayMonth
        self.birthdayDay = birthdayDay
        self.ownerMemberId = ownerMemberId
        self.note = note
    }
}

public struct GiftIdeaDraft: Sendable, Equatable {
    public var title: String
    public var url: String?
    public var price: Double?
    public var currency: String?
    public var note: String?

    public init(
        title: String,
        url: String? = nil,
        price: Double? = nil,
        currency: String? = nil,
        note: String? = nil
    ) {
        self.title = title
        self.url = url
        self.price = price
        self.currency = currency
        self.note = note
    }
}

public protocol PeopleRepository: Sendable {
    func create(_ draft: PersonDraft) async throws -> PersonDTO
    func update(_ person: PersonDTO) async throws -> PersonDTO
    func person(id: UUID) async throws -> PersonDTO?
    func people(spaceId: UUID) async throws -> [PersonDTO]
    func delete(id: UUID) async throws
    func addGiftIdea(personId: UUID, draft: GiftIdeaDraft) async throws -> GiftIdeaDTO
    func updateGiftIdea(_ idea: GiftIdeaDTO) async throws -> GiftIdeaDTO
    func giftIdeas(personId: UUID) async throws -> [GiftIdeaDTO]
    func deleteGiftIdea(id: UUID) async throws
}
