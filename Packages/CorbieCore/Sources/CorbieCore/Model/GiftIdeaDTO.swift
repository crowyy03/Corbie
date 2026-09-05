import Foundation

public struct GiftIdeaDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var personId: UUID?
    public var title: String
    public var url: String?
    public var price: Double?
    public var currency: String?
    public var note: String?
    public var isDone: Bool

    public init(
        id: UUID,
        personId: UUID? = nil,
        title: String = "",
        url: String? = nil,
        price: Double? = nil,
        currency: String? = nil,
        note: String? = nil,
        isDone: Bool = false
    ) {
        self.id = id
        self.personId = personId
        self.title = title
        self.url = url
        self.price = price
        self.currency = currency
        self.note = note
        self.isDone = isDone
    }

    public init(_ idea: GiftIdea) {
        self.init(
            id: idea.id ?? UUID(),
            personId: idea.person?.id,
            title: idea.title ?? "",
            url: idea.url,
            price: idea.price?.doubleValue,
            currency: idea.currency,
            note: idea.note,
            isDone: idea.isDone
        )
    }
}
