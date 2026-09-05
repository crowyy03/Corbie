import CoreData
import Foundation

public struct CoreDataVoteRepository: VoteRepository {
    private let access: CoreDataAccess

    public init(stack: CoreDataStack) {
        access = CoreDataAccess(stack: stack)
    }

    public func create(_ draft: VoteDraft) async throws -> VoteDTO {
        let question = draft.question.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = draft.options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
        guard question.isEmpty == false else {
            throw CorbieError.invalidInput("vote question is empty")
        }
        guard options.count >= VoteDTO.minOptions, options.count <= VoteDTO.maxOptions else {
            throw CorbieError.invalidInput("a vote needs \(VoteDTO.minOptions) to \(VoteDTO.maxOptions) options")
        }
        return try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: draft.spaceId, in: context)
            let vote = Vote(context: context)
            context.assign(vote, toStoreOf: space)
            vote.space = space
            vote.question = question
            vote.options = options
            vote.mode = draft.mode
            vote.revealWhenBothAnswered = draft.revealWhenBothAnswered
            vote.createdByMemberId = draft.createdByMemberId
            return VoteDTO(vote)
        }
    }

    public func respond(voteId: UUID, memberId: UUID, optionIndexes: [Int], at date: Date) async throws -> VoteDTO {
        try await access.write { context in
            let vote: Vote = try ManagedFetch.require(Vote.entityName, id: voteId, in: context)
            let options = vote.options
            let choices = Array(Set(optionIndexes)).sorted()
            guard choices.isEmpty == false, choices.allSatisfy({ $0 >= 0 && $0 < options.count }) else {
                throw CorbieError.invalidInput("vote answer is out of range")
            }
            if vote.mode == .single, choices.count > 1 {
                throw CorbieError.invalidInput("this vote takes one option")
            }
            let answer: VoteResponse
            if let existing = vote.responses.first(where: { $0.memberId == memberId }) {
                answer = existing
            } else {
                answer = VoteResponse(context: context)
                context.assign(answer, toStoreOf: vote)
                answer.vote = vote
                answer.memberId = memberId
            }
            answer.optionIndexes = choices
            answer.answeredAt = date

            let memberCount = vote.space?.members.count ?? 0
            let answered = VoteResponses(vote.responses).memberCount
            if vote.revealedAt == nil, memberCount > 0, answered >= memberCount {
                vote.revealedAt = date
            }
            return VoteDTO(vote)
        }
    }

    public func reveal(voteId: UUID, at date: Date) async throws -> VoteDTO {
        try await access.write { context in
            let vote: Vote = try ManagedFetch.require(Vote.entityName, id: voteId, in: context)
            if vote.revealedAt == nil {
                vote.revealedAt = date
            }
            return VoteDTO(vote)
        }
    }

    public func vote(id: UUID) async throws -> VoteDTO? {
        try await access.read { context in
            let vote: Vote? = try ManagedFetch.first(Vote.entityName, id: id, in: context)
            return vote.map(VoteDTO.init)
        }
    }

    public func votes(spaceId: UUID) async throws -> [VoteDTO] {
        try await access.read { context in
            let votes: [Vote] = try ManagedFetch.all(
                Vote.entityName,
                predicate: ManagedFetch.spaceRelation(spaceId),
                sort: [NSSortDescriptor(key: "createdAt", ascending: false)],
                in: context
            )
            return votes.map(VoteDTO.init)
        }
    }

    public func delete(id: UUID) async throws {
        try await access.write { context in
            guard let vote: Vote = try ManagedFetch.first(Vote.entityName, id: id, in: context) else { return }
            context.delete(vote)
        }
    }
}
