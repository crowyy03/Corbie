import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainTodayFeedTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "UTC")

    private func date(_ value: String) -> Date {
        DomainClock.date(value, in: calendar)
    }

    private var wednesday: Date { date("2026-09-02 09:00") }

    private func provider(_ world: TestWorld) -> TodayFeedProvider {
        TodayFeedProvider(repositories: world.repositories, calendar: calendar)
    }

    private func feed(_ world: TestWorld, now: Date? = nil) async throws -> TodayFeed {
        let space = try await world.repositories.spaces.space(id: world.space.id) ?? world.space
        return try await provider(world).feed(
            space: space,
            viewerMemberId: world.me.id,
            now: now ?? wednesday
        )
    }

    @Test func anUntouchedSpaceRendersNothing() async throws {
        let world = try await TestWorld.make()
        let result = try await feed(world)
        #expect(result.isEmpty)
        #expect(result.blocks.isEmpty)
        #expect(result.daysTogether == nil)
        #expect(result.isPaired)
    }

    @Test func allDayEntriesComeFirstAndTheRestFollowTheClock() async throws {
        let world = try await TestWorld.make()
        _ = try await world.repositories.events.create(
            EventDraft(
                spaceId: world.space.id,
                title: "Dinner",
                startAt: date("2026-09-02 19:00"),
                createdByMemberId: world.me.id
            )
        )
        _ = try await world.repositories.events.create(
            EventDraft(
                spaceId: world.space.id,
                title: "Holiday",
                startAt: date("2026-09-02"),
                isAllDay: true,
                createdByMemberId: world.partner.id
            )
        )
        _ = try await world.repositories.tasks.create(
            TaskDraft(
                spaceId: world.space.id,
                title: "Vet",
                assigneeMemberId: world.me.id,
                dueAt: date("2026-09-02"),
                createdByMemberId: world.me.id
            )
        )
        _ = try await world.repositories.tasks.create(
            TaskDraft(
                spaceId: world.space.id,
                title: "Tomorrow",
                dueAt: date("2026-09-03"),
                createdByMemberId: world.me.id
            )
        )
        let result = try await feed(world)
        #expect(result.entries.map(\.title) == ["Holiday", "Vet", "Dinner"])
        #expect(result.entries.map(\.isAllDay) == [true, true, false])
        #expect(result.blocks.first == .today)
    }

    @Test func aDatedPlanStepArrivesWithItsPlan() async throws {
        let world = try await TestWorld.make()
        let plan = try await world.repositories.plans.create(
            PlanDraft(spaceId: world.space.id, title: "Japan", createdByMemberId: world.me.id)
        )
        _ = try await world.repositories.plans.addStep(
            planId: plan.id,
            draft: PlanStepDraft(title: "Papers", assigneeMemberId: world.me.id, dueAt: date("2026-09-02"))
        )
        let result = try await feed(world)
        let entry = try #require(result.entries.first)
        #expect(entry.title == "Papers")
        #expect(entry.planTitle == "Japan")
        #expect(entry.planId == plan.id)
        #expect(entry.task != nil)
    }

    @Test func freeTasksStopAtThreeAndCountTheRest() async throws {
        let world = try await TestWorld.make()
        for index in 1...5 {
            _ = try await world.repositories.tasks.create(
                TaskDraft(
                    spaceId: world.space.id,
                    title: "Free " + String(index),
                    createdByMemberId: world.me.id
                )
            )
        }
        let result = try await feed(world)
        #expect(result.freeTasks.count == 3)
        #expect(result.freeTasksRemaining == 2)
        #expect(result.freeTasks.allSatisfy { $0.isFree })
    }

    @Test func aFreeTaskDueTodayIsNotListedTwice() async throws {
        let world = try await TestWorld.make()
        _ = try await world.repositories.tasks.create(
            TaskDraft(
                spaceId: world.space.id,
                title: "Bins",
                dueAt: date("2026-09-02"),
                createdByMemberId: world.me.id
            )
        )
        let result = try await feed(world)
        #expect(result.entries.map(\.title) == ["Bins"])
        #expect(result.freeTasks.isEmpty)
        #expect(result.freeTasksRemaining == 0)
    }

    @Test func aBirthdayWithinTwoWeeksAndNoGiftIsFlagged() async throws {
        let world = try await TestWorld.make()
        var partner = world.partner
        partner.birthdayMonth = 9
        partner.birthdayDay = 8
        _ = try await world.repositories.members.update(partner)
        _ = try await world.repositories.wishes.create(
            WishDraft(
                spaceId: world.space.id,
                ownerMemberId: world.partner.id,
                addedByMemberId: world.partner.id,
                title: "Wool scarf"
            )
        )
        let result = try await feed(world)
        let birthday = try #require(result.comingUp.first { $0.kind == .memberBirthday })
        #expect(birthday.daysAway == 6)
        #expect(birthday.isGiftMissing)
        #expect(birthday.ideasCount == 1)
        #expect(birthday.memberId == world.partner.id)
    }

    @Test func aDateFurtherOutCarriesNoRadar() async throws {
        let world = try await TestWorld.make()
        var partner = world.partner
        partner.birthdayMonth = 12
        partner.birthdayDay = 1
        _ = try await world.repositories.members.update(partner)
        let result = try await feed(world)
        let birthday = try #require(result.comingUp.first { $0.kind == .memberBirthday })
        #expect(birthday.radar == nil)
        #expect(birthday.isGiftMissing == false)
    }

    @Test func thePlanWithTheNearestDeadlineWins() async throws {
        let world = try await TestWorld.make()
        _ = try await world.repositories.plans.create(
            PlanDraft(
                spaceId: world.space.id,
                title: "Far",
                targetAmount: 1000,
                endAt: date("2027-01-01"),
                createdByMemberId: world.me.id
            )
        )
        _ = try await world.repositories.plans.create(
            PlanDraft(
                spaceId: world.space.id,
                title: "Near",
                targetAmount: 1000,
                endAt: date("2026-10-01"),
                createdByMemberId: world.me.id
            )
        )
        let result = try await feed(world)
        #expect(result.plan?.title == "Near")
    }

    @Test func withoutADeadlineTheNewestPlanShows() async throws {
        let world = try await TestWorld.make()
        _ = try await world.repositories.plans.create(
            PlanDraft(spaceId: world.space.id, title: "Older", createdByMemberId: world.me.id)
        )
        _ = try await world.repositories.plans.create(
            PlanDraft(spaceId: world.space.id, title: "Newer", createdByMemberId: world.me.id)
        )
        let result = try await feed(world)
        #expect(result.plan?.title == "Newer")
    }

    @Test func waitingCollectsACapsuleAVoteAndFreshPartnerWishes() async throws {
        let world = try await TestWorld.make()
        _ = try await world.repositories.capsules.create(
            CapsuleDraft(
                spaceId: world.space.id,
                authorMemberId: world.partner.id,
                recipientMemberId: world.me.id,
                title: "Read me",
                body: "Hello",
                opensAt: date("2026-09-01 09:00")
            ),
            now: date("2026-08-01 09:00")
        )
        _ = try await world.repositories.votes.create(
            VoteDraft(
                spaceId: world.space.id,
                question: "Pizza or sushi",
                options: ["Pizza", "Sushi"],
                createdByMemberId: world.partner.id
            )
        )
        _ = try await world.repositories.members.markUsVisited(
            memberId: world.me.id,
            at: date("2026-09-01 09:00")
        )
        _ = try await world.repositories.wishes.create(
            WishDraft(
                spaceId: world.space.id,
                ownerMemberId: world.partner.id,
                addedByMemberId: world.partner.id,
                title: "Boots"
            )
        )
        let result = try await feed(world)
        #expect(result.waiting.count == 3)
        #expect(result.waiting.contains { if case .capsule = $0 { return true } else { return false } })
        #expect(result.waiting.contains { if case .vote = $0 { return true } else { return false } })
        #expect(result.waiting.contains { $0 == .partnerWishes(count: 1) })
    }

    @Test func aWishAddedBeforeTheLastVisitIsNotWaiting() async throws {
        let world = try await TestWorld.make()
        let wish = try await world.repositories.wishes.create(
            WishDraft(
                spaceId: world.space.id,
                ownerMemberId: world.partner.id,
                addedByMemberId: world.partner.id,
                title: "Boots"
            )
        )
        let createdAt = try #require(wish.createdAt)
        _ = try await world.repositories.members.markUsVisited(
            memberId: world.me.id,
            at: createdAt.addingTimeInterval(1)
        )
        let result = try await feed(world)
        #expect(result.waiting.isEmpty)
    }

    @Test func anAnsweredVoteAndAnOpenedCapsuleStopWaiting() async throws {
        let world = try await TestWorld.make()
        let capsule = try await world.repositories.capsules.create(
            CapsuleDraft(
                spaceId: world.space.id,
                authorMemberId: world.partner.id,
                recipientMemberId: world.me.id,
                title: "Read me",
                body: "Hello",
                opensAt: date("2026-09-01 09:00")
            ),
            now: date("2026-08-01 09:00")
        )
        _ = try await world.repositories.capsules.markOpened(
            capsuleId: capsule.id,
            memberId: world.me.id,
            at: date("2026-09-01 10:00")
        )
        let vote = try await world.repositories.votes.create(
            VoteDraft(
                spaceId: world.space.id,
                question: "Pizza or sushi",
                options: ["Pizza", "Sushi"],
                createdByMemberId: world.partner.id
            )
        )
        _ = try await world.repositories.votes.respond(
            voteId: vote.id,
            memberId: world.me.id,
            optionIndexes: [0],
            at: date("2026-09-01 11:00")
        )
        let result = try await feed(world)
        #expect(result.waiting.isEmpty)
    }

    @Test func daysTogetherComeFromTheSpace() async throws {
        let world = try await TestWorld.make()
        var space = world.space
        space.togetherSince = date("2023-03-31")
        _ = try await world.repositories.spaces.update(space)
        let result = try await feed(world)
        #expect(result.daysTogether == 1251)
    }

    @Test func theRecapCardOnlyArrivesInsideItsWindow() async throws {
        let world = try await TestWorld.make()
        _ = try await world.repositories.tasks.create(
            TaskDraft(spaceId: world.space.id, title: "Bins", createdByMemberId: world.me.id)
        )
        let quiet = try await feed(world)
        #expect(quiet.recap == nil)
        let sundayEvening = date("2026-09-06 20:00")
        let result = try await feed(world, now: sundayEvening)
        let recap = try #require(result.recap)
        #expect(recap.isPaired)
        #expect(result.blocks.last == .recap)
    }

    @Test func markingTheRecapSeenTakesTheCardAway() async throws {
        let world = try await TestWorld.make()
        let sundayEvening = date("2026-09-06 20:00")
        let before = try await feed(world, now: sundayEvening)
        #expect(before.recap != nil)
        _ = try await world.repositories.members.markRecapSeen(
            memberId: world.me.id,
            at: date("2026-09-06 20:05")
        )
        let after = try await feed(world, now: sundayEvening)
        #expect(after.recap == nil)
    }

    @Test func aSoloSpaceKnowsItIsAlone() async throws {
        let world = try await TestWorld.make(withPartner: false)
        let result = try await feed(world)
        #expect(result.isPaired == false)
    }
}
