import Foundation

public struct ChoreRatingDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var choreItemId: UUID?
    public var memberId: UUID?
    public var verdict: ChoreVerdict
    public var createdAt: Date?

    public init(
        id: UUID,
        choreItemId: UUID? = nil,
        memberId: UUID? = nil,
        verdict: ChoreVerdict = .neutral,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.choreItemId = choreItemId
        self.memberId = memberId
        self.verdict = verdict
        self.createdAt = createdAt
    }

    public init(_ rating: ChoreRating) {
        self.init(
            id: rating.id ?? UUID(),
            choreItemId: rating.choreItem?.id,
            memberId: rating.memberId,
            verdict: rating.verdict,
            createdAt: rating.createdAt
        )
    }
}
