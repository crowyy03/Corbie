import Foundation

public struct VoteDTO: Sendable, Codable, Identifiable, Equatable {
    public static let minOptions = 2
    public static let maxOptions = 4

    public let id: UUID
    public var spaceId: UUID?
    public var question: String
    public var options: [String]
    public var mode: VoteMode
    public var createdByMemberId: UUID?
    public var responses: VoteResponses
    public var revealWhenBothAnswered: Bool
    public var revealedAt: Date?
    public var createdAt: Date?

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        question: String = "",
        options: [String] = [],
        mode: VoteMode = .single,
        createdByMemberId: UUID? = nil,
        responses: VoteResponses = VoteResponses(),
        revealWhenBothAnswered: Bool = true,
        revealedAt: Date? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.question = question
        self.options = options
        self.mode = mode
        self.createdByMemberId = createdByMemberId
        self.responses = responses
        self.revealWhenBothAnswered = revealWhenBothAnswered
        self.revealedAt = revealedAt
        self.createdAt = createdAt
    }

    public init(_ vote: Vote) {
        self.init(
            id: vote.id ?? UUID(),
            spaceId: vote.space?.id,
            question: vote.question ?? "",
            options: vote.options,
            mode: vote.mode,
            createdByMemberId: vote.createdByMemberId,
            responses: VoteResponses(vote.responses),
            revealWhenBothAnswered: vote.revealWhenBothAnswered,
            revealedAt: vote.revealedAt,
            createdAt: vote.createdAt
        )
    }

    public var isRevealed: Bool { revealedAt != nil }

    public func canReveal(memberCount: Int) -> Bool {
        guard revealWhenBothAnswered else { return true }
        return memberCount > 0 && responses.memberCount >= memberCount
    }

    public func canSeeResults(as memberId: UUID) -> Bool {
        guard responses.hasAnswered(memberId) else { return false }
        return isRevealed || revealWhenBothAnswered == false
    }

    public var matchingOptions: [Int] { responses.matches(optionCount: options.count) }
}
