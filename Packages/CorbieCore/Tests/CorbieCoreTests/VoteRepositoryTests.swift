import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct VoteRepositoryTests {
    @Test func revealWaitsForBothAnswers() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.votes
        let vote = try await repository.create(
            VoteDraft(
                spaceId: world.space.id,
                question: "Where to eat",
                options: ["Ramen", "Pasta", "Tacos"],
                createdByMemberId: world.me.id
            )
        )
        #expect(vote.isRevealed == false)

        let afterMe = try await repository.respond(voteId: vote.id, memberId: world.me.id, optionIndexes: [0])
        #expect(afterMe.isRevealed == false)
        #expect(afterMe.canSeeResults(as: world.me.id) == false)
        #expect(afterMe.responses[world.me.id] == [0])

        let afterPartner = try await repository.respond(
            voteId: vote.id,
            memberId: world.partner.id,
            optionIndexes: [0]
        )
        #expect(afterPartner.isRevealed)
        #expect(afterPartner.canSeeResults(as: world.me.id))
        #expect(afterPartner.matchingOptions == [0])
    }

    @Test func withoutTheGateAnsweringUnlocksResultsOnlyForTheAnswerer() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.votes
        let vote = try await repository.create(
            VoteDraft(
                spaceId: world.space.id,
                question: "Beach or mountains",
                options: ["Beach", "Mountains"],
                revealWhenBothAnswered: false
            )
        )
        let answered = try await repository.respond(voteId: vote.id, memberId: world.me.id, optionIndexes: [1])
        #expect(answered.isRevealed == false)
        #expect(answered.canSeeResults(as: world.me.id))
        #expect(answered.canSeeResults(as: world.partner.id) == false)
    }

    @Test func aRevealedVoteStillHidesResultsFromWhoeverHasNotAnswered() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.votes
        let vote = try await repository.create(
            VoteDraft(spaceId: world.space.id, question: "Film", options: ["Dune", "Arrival"])
        )
        _ = try await repository.respond(voteId: vote.id, memberId: world.me.id, optionIndexes: [0])
        let revealed = try await repository.reveal(voteId: vote.id)
        #expect(revealed.isRevealed)
        #expect(revealed.canSeeResults(as: world.me.id))
        #expect(revealed.canSeeResults(as: world.partner.id) == false)
    }

    @Test func twoContextsEachRecordTheirOwnAnswer() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.votes
        let vote = try await repository.create(
            VoteDraft(spaceId: world.space.id, question: "Where to eat", options: ["Ramen", "Pasta"])
        )
        let mine = isolatedContext(in: world)
        let theirs = isolatedContext(in: world)
        try load(voteId: vote.id, in: mine)
        try load(voteId: vote.id, in: theirs)
        try answer(voteId: vote.id, memberId: world.me.id, choice: 0, in: mine)
        try answer(voteId: vote.id, memberId: world.partner.id, choice: 1, in: theirs)

        let stored = try #require(try await repository.vote(id: vote.id))
        #expect(stored.responses[world.me.id] == [0])
        #expect(stored.responses[world.partner.id] == [1])
    }

    private func isolatedContext(in world: TestWorld) -> NSManagedObjectContext {
        let context = world.controller.stack.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = false
        return context
    }

    private func load(voteId: UUID, in context: NSManagedObjectContext) throws {
        try context.performAndWait {
            _ = try ManagedFetch.require(Vote.entityName, id: voteId, in: context) as Vote
        }
    }

    private func answer(voteId: UUID, memberId: UUID, choice: Int, in context: NSManagedObjectContext) throws {
        try context.performAndWait {
            let vote: Vote = try ManagedFetch.require(Vote.entityName, id: voteId, in: context)
            let answer = VoteResponse(context: context)
            answer.vote = vote
            answer.memberId = memberId
            answer.optionIndexes = [choice]
            try context.save()
        }
    }

    @Test func multiModeKeepsOnlyTheIntersection() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.votes
        let vote = try await repository.create(
            VoteDraft(
                spaceId: world.space.id,
                question: "Where to eat",
                options: ["Ramen", "Pasta", "Tacos", "Pizza"],
                mode: .multi
            )
        )
        _ = try await repository.respond(voteId: vote.id, memberId: world.me.id, optionIndexes: [0, 1, 3])
        let final = try await repository.respond(
            voteId: vote.id,
            memberId: world.partner.id,
            optionIndexes: [1, 3]
        )
        #expect(final.matchingOptions == [1, 3])
    }

    @Test func singleModeTakesOneOption() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.votes
        let vote = try await repository.create(
            VoteDraft(spaceId: world.space.id, question: "Film", options: ["Dune", "Arrival"])
        )
        await #expect(throws: CorbieError.invalidInput("this vote takes one option")) {
            _ = try await repository.respond(voteId: vote.id, memberId: world.me.id, optionIndexes: [0, 1])
        }
        await #expect(throws: CorbieError.invalidInput("vote answer is out of range")) {
            _ = try await repository.respond(voteId: vote.id, memberId: world.me.id, optionIndexes: [7])
        }
    }

    @Test func aVoteNeedsTwoToFourOptions() async throws {
        let world = try await TestWorld.make()
        await #expect(throws: CorbieError.invalidInput("a vote needs 2 to 4 options")) {
            _ = try await world.repositories.votes.create(
                VoteDraft(spaceId: world.space.id, question: "One", options: ["Only"])
            )
        }
    }

    @Test func manualRevealKeepsTheFirstTimestamp() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.votes
        let vote = try await repository.create(
            VoteDraft(spaceId: world.space.id, question: "Weekend", options: ["Home", "Away"])
        )
        let at = Date(timeIntervalSince1970: 1_757_000_000)
        let revealed = try await repository.reveal(voteId: vote.id, at: at)
        let again = try await repository.reveal(voteId: vote.id, at: at.addingTimeInterval(60))
        #expect(revealed.revealedAt == at)
        #expect(again.revealedAt == at)
    }
}
