import Foundation

public struct EventCommentDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var eventId: UUID?
    public var memberId: UUID?
    public var text: String
    public var createdAt: Date?

    public init(
        id: UUID,
        eventId: UUID? = nil,
        memberId: UUID? = nil,
        text: String = "",
        createdAt: Date? = nil
    ) {
        self.id = id
        self.eventId = eventId
        self.memberId = memberId
        self.text = text
        self.createdAt = createdAt
    }

    public init(_ comment: EventComment) {
        self.init(
            id: comment.id ?? UUID(),
            eventId: comment.event?.id,
            memberId: comment.memberId,
            text: comment.text ?? "",
            createdAt: comment.createdAt
        )
    }
}
