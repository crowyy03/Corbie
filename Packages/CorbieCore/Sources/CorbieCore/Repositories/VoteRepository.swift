import Foundation

public struct VoteDraft: Sendable, Equatable {
    public var spaceId: UUID
    public var question: String
    public var options: [String]
    public var mode: VoteMode
    public var revealWhenBothAnswered: Bool
    public var createdByMemberId: UUID?

    public init(
        spaceId: UUID,
        question: String,
        options: [String],
        mode: VoteMode = .single,
        revealWhenBothAnswered: Bool = true,
        createdByMemberId: UUID? = nil
    ) {
        self.spaceId = spaceId
        self.question = question
        self.options = options
        self.mode = mode
        self.revealWhenBothAnswered = revealWhenBothAnswered
        self.createdByMemberId = createdByMemberId
    }
}

public protocol VoteRepository: Sendable {
    func create(_ draft: VoteDraft) async throws -> VoteDTO
    func respond(voteId: UUID, memberId: UUID, optionIndexes: [Int], at date: Date) async throws -> VoteDTO
    func reveal(voteId: UUID, at date: Date) async throws -> VoteDTO
    func vote(id: UUID) async throws -> VoteDTO?
    func votes(spaceId: UUID) async throws -> [VoteDTO]
    func delete(id: UUID) async throws
}

extension VoteRepository {
    public func respond(voteId: UUID, memberId: UUID, optionIndexes: [Int]) async throws -> VoteDTO {
        try await respond(voteId: voteId, memberId: memberId, optionIndexes: optionIndexes, at: Date())
    }

    public func reveal(voteId: UUID) async throws -> VoteDTO {
        try await reveal(voteId: voteId, at: Date())
    }
}
