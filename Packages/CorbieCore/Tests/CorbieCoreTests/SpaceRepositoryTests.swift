import Foundation
import Testing
@testable import CorbieCore

@Suite struct SpaceRepositoryTests {
    @Test func createStartsASevenDayTrial() async throws {
        let controller = PersistenceController.inMemory()
        let now = Date(timeIntervalSince1970: 1_757_000_000)
        let space = try await controller.repositories.spaces.create(
            displayCurrency: "EUR",
            creatorMemberId: nil,
            now: now
        )
        let expected = Calendar.utc.date(byAdding: .day, value: 7, to: now)
        #expect(space.displayCurrency == "EUR")
        #expect(space.subscriptionStatus == .trial)
        #expect(space.trialEndsAt == expected)
        #expect(space.trialActive(at: now))
        #expect(space.trialActive(at: expected?.addingTimeInterval(1) ?? now) == false)
    }

    @Test func twoMembersMakeTheSpacePaired() async throws {
        let world = try await TestWorld.make()
        let space = try #require(try await world.repositories.spaces.space(id: world.space.id))
        #expect(space.memberCount == 2)
        #expect(space.isPaired)
    }

    @Test func extendTrialNeverShortensIt() async throws {
        let controller = PersistenceController.inMemory()
        let repository = controller.repositories.spaces
        let now = Date(timeIntervalSince1970: 1_757_000_000)
        let space = try await repository.create(displayCurrency: "USD", creatorMemberId: nil, now: now)
        let earlier = try await repository.extendTrial(spaceId: space.id, days: 1, now: now)
        #expect(earlier.trialEndsAt == space.trialEndsAt)

        let later = now.addingTimeInterval(60 * 60 * 24 * 5)
        let extended = try await repository.extendTrial(spaceId: space.id, days: 7, now: later)
        #expect(try #require(extended.trialEndsAt) > #require(space.trialEndsAt))
    }

    @Test func settingsRoundTrip() async throws {
        let world = try await TestWorld.make()
        var space = world.space
        space.togetherSince = Date(timeIntervalSince1970: 1_600_000_000)
        space.weddingDate = Date(timeIntervalSince1970: 1_700_000_000)
        space.displayCurrency = "GBP"
        let saved = try await world.repositories.spaces.update(space)
        #expect(saved.displayCurrency == "GBP")
        #expect(saved.togetherSince == space.togetherSince)
        #expect(saved.weddingDate == space.weddingDate)
    }

    @Test func deletingSpaceRemovesEveryChild() async throws {
        let world = try await TestWorld.make()
        let repositories = world.repositories
        let spaceId = world.space.id

        _ = try await repositories.tasks.create(TaskDraft(spaceId: spaceId, title: "Buy milk"))
        let event = try await repositories.events.create(
            EventDraft(spaceId: spaceId, title: "Dinner", startAt: Date())
        )
        _ = try await repositories.events.addComment(eventId: event.id, memberId: world.me.id, text: "Table for two")
        _ = try await repositories.wishes.create(WishDraft(spaceId: spaceId, ownerMemberId: world.me.id, title: "Lamp"))
        let goal = try await repositories.goals.create(
            GoalDraft(spaceId: spaceId, title: "Lisbon", targetAmount: 1000, currency: "USD")
        )
        _ = try await repositories.goals.addExpense(goalId: goal.id, draft: GoalExpenseDraft(amount: 10, currency: "USD"))
        _ = try await repositories.goals.addStep(goalId: goal.id, draft: GoalStepDraft(title: "Pack"))
        let folder = try await repositories.tasks.createFolder(
            TaskFolderDraft(spaceId: spaceId, title: "Places", template: .places)
        )
        _ = try await repositories.tasks.create(
            TaskDraft(spaceId: spaceId, title: "Belem", folderId: folder.id)
        )
        _ = try await repositories.busyIntervals.replace(
            spaceId: spaceId,
            memberId: world.me.id,
            source: .device,
            intervals: [BusyIntervalDraft(startAt: Date(), endAt: Date().addingTimeInterval(3600))]
        )
        _ = try await repositories.capsules.create(
            CapsuleDraft(
                spaceId: spaceId,
                title: "Letter",
                body: "See you",
                opensAt: Date().addingTimeInterval(86_400)
            )
        )
        _ = try await repositories.votes.create(
            VoteDraft(spaceId: spaceId, question: "Where to eat", options: ["Ramen", "Pasta"])
        )
        let person = try await repositories.people.create(PersonDraft(spaceId: spaceId, name: "Anna"))
        _ = try await repositories.people.addGiftIdea(personId: person.id, draft: GiftIdeaDraft(title: "Book"))

        try await repositories.spaces.delete(id: spaceId)

        let entities = [
            "Space", "Member", "TaskItem", "TaskFolder", "Event", "EventComment", "Wish", "Goal",
            "GoalExpense", "GoalStep", "BusyInterval", "Capsule", "Vote", "Person", "GiftIdea"
        ]
        for entity in entities {
            #expect(try world.count(entity) == 0, "\(entity) survived the space deletion")
        }
    }
}
