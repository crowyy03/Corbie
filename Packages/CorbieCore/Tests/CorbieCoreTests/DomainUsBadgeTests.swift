import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainUsBadgeTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "Europe/Berlin")
    private let viewerId = UUID()
    private let partnerId = UUID()

    private var rule: UsBadgeRule { UsBadgeRule(calendar: calendar) }
    private var now: Date { DomainClock.date("2026-09-05 12:00", in: calendar) }

    private func input(
        lastUsVisitAt: Date? = nil,
        partnerBirthday: (month: Int, day: Int)? = nil,
        people: [PersonDTO] = [],
        capsules: [CapsuleDTO] = [],
        votes: [VoteDTO] = [],
        wishes: [WishDTO] = []
    ) -> UsBadgeInput {
        UsBadgeInput(
            space: SpaceDTO(id: UUID()),
            viewer: MemberDTO(id: viewerId, displayName: "Ilya", lastUsVisitAt: lastUsVisitAt),
            partner: MemberDTO(
                id: partnerId,
                displayName: "Sofia",
                birthdayMonth: partnerBirthday?.month,
                birthdayDay: partnerBirthday?.day
            ),
            people: people,
            capsules: capsules,
            votes: votes,
            wishes: wishes
        )
    }

    private func partnerWish(added: String, by memberId: UUID) -> WishDTO {
        WishDTO(
            id: UUID(),
            ownerMemberId: partnerId,
            addedByMemberId: memberId,
            title: "Apron",
            createdAt: DomainClock.date(added, in: calendar)
        )
    }

    @Test func aQuietSpaceShowsNoDot() {
        #expect(rule.showsDot(input(), now: now) == false)
    }

    @Test func aCapsuleTheViewerCanOpenShowsTheDot() {
        let ready = CapsuleDTO(
            id: UUID(),
            authorMemberId: partnerId,
            recipientMemberId: viewerId,
            title: "Read me",
            opensAt: DomainClock.date("2026-09-01 09:00", in: calendar)
        )
        #expect(rule.showsDot(input(capsules: [ready]), now: now))

        var opened = ready
        opened.openedByMemberIds = [viewerId]
        #expect(rule.showsDot(input(capsules: [opened]), now: now) == false)

        var sealed = ready
        sealed.opensAt = DomainClock.date("2026-12-01 09:00", in: calendar)
        #expect(rule.showsDot(input(capsules: [sealed]), now: now) == false)
    }

    @Test func aCapsuleTheViewerWroteAlsoWaitsToBeOpened() {
        let mine = CapsuleDTO(
            id: UUID(),
            authorMemberId: viewerId,
            recipientMemberId: partnerId,
            title: "Read me",
            opensAt: DomainClock.date("2026-09-01 09:00", in: calendar),
            openedByMemberIds: [partnerId]
        )
        #expect(rule.showsDot(input(capsules: [mine]), now: now))
    }

    @Test func aVoteWithoutTheViewersAnswerShowsTheDot() {
        let vote = VoteDTO(
            id: UUID(),
            question: "Where to eat",
            options: ["Sushi", "Pasta"],
            createdByMemberId: partnerId
        )
        #expect(rule.showsDot(input(votes: [vote]), now: now))

        var answered = vote
        answered.responses[viewerId] = [0]
        #expect(rule.showsDot(input(votes: [answered]), now: now) == false)
    }

    @Test func aWishThePartnerAddedSinceTheLastVisitShowsTheDot() {
        let visit = DomainClock.date("2026-09-04 20:00", in: calendar)
        let fresh = partnerWish(added: "2026-09-05 08:00", by: partnerId)
        #expect(rule.showsDot(input(lastUsVisitAt: visit, wishes: [fresh]), now: now))

        let seen = partnerWish(added: "2026-09-03 08:00", by: partnerId)
        #expect(rule.showsDot(input(lastUsVisitAt: visit, wishes: [seen]), now: now) == false)

        let mine = partnerWish(added: "2026-09-05 08:00", by: viewerId)
        #expect(rule.showsDot(input(lastUsVisitAt: visit, wishes: [mine]), now: now) == false)
    }

    @Test func aWishCountsWhenTheHubHasNeverBeenOpened() {
        let fresh = partnerWish(added: "2026-09-05 08:00", by: partnerId)
        #expect(rule.showsDot(input(wishes: [fresh]), now: now))
    }

    @Test func aBirthdayWithNoGiftPickedShowsTheDot() {
        let anna = PersonDTO(id: UUID(), name: "Anna", birthdayMonth: 9, birthdayDay: 12, giftIdeaCount: 2)
        #expect(rule.showsDot(input(people: [anna]), now: now))

        var covered = anna
        covered.hasPickedGift = true
        #expect(rule.showsDot(input(people: [covered]), now: now) == false)

        let far = PersonDTO(id: UUID(), name: "Mark", birthdayMonth: 11, birthdayDay: 2)
        #expect(rule.showsDot(input(people: [far]), now: now) == false)
    }

    @Test func thePartnerBirthdayRunsOnTheirOpenWishes() {
        #expect(rule.showsDot(input(partnerBirthday: (month: 9, day: 12)), now: now))

        var bought = partnerWish(added: "2026-08-01 10:00", by: viewerId)
        bought.isFulfilled = true
        bought.fulfilledAt = DomainClock.date("2026-09-01 10:00", in: calendar)
        #expect(rule.showsDot(input(partnerBirthday: (month: 9, day: 12), wishes: [bought]), now: now) == false)
    }

    @Test func todaysQuestionShowsTheDotUntilYouAnswerOrLook() {
        let today = DailyQuestionDTO(id: UUID(), dayKey: "2026-09-05")
        #expect(rule.showsDot(questionInput(today), now: now))

        var answered = today
        answered.answers = [QuestionAnswerDTO(id: UUID(), memberId: viewerId, text: "A dog on the tram")]
        #expect(rule.showsDot(questionInput(answered), now: now) == false)

        #expect(rule.showsDot(questionInput(today, lastSeenDayKey: "2026-09-05"), now: now) == false)
        #expect(rule.showsDot(questionInput(today, lastSeenDayKey: "2026-09-04"), now: now))
        #expect(rule.showsDot(questionInput(nil), now: now) == false)
    }

    @Test func aSpaceWithNobodyElseInItIsNeverDottedByTheQuestion() {
        let today = DailyQuestionDTO(id: UUID(), dayKey: "2026-09-05")
        #expect(rule.showsDot(questionInput(today, memberCount: 1), now: now) == false)
    }

    private func questionInput(
        _ question: DailyQuestionDTO?,
        lastSeenDayKey: String? = nil,
        memberCount: Int = 2
    ) -> UsBadgeInput {
        UsBadgeInput(
            space: SpaceDTO(id: UUID(), memberCount: memberCount),
            viewer: MemberDTO(
                id: viewerId,
                displayName: "Ilya",
                lastUsVisitAt: now,
                lastQuestionSeenDayKey: lastSeenDayKey
            ),
            partner: MemberDTO(id: partnerId, displayName: "Sofia"),
            question: question
        )
    }

    @Test func theViewersOwnBirthdayIsNotAGiftToPick() {
        let input = UsBadgeInput(
            space: SpaceDTO(id: UUID()),
            viewer: MemberDTO(id: viewerId, displayName: "Ilya", birthdayMonth: 9, birthdayDay: 12),
            partner: MemberDTO(id: partnerId, displayName: "Sofia")
        )
        #expect(rule.showsDot(input, now: now) == false)
    }
}

@MainActor
@Suite struct DomainUsBadgeProviderTests {
    private func provider(_ world: TestWorld) -> UsBadgeProvider {
        UsBadgeProvider(repositories: world.repositories, now: { Date(timeIntervalSinceNow: 3600) })
    }

    @Test func openingTheHubClearsAWishTheDotWasRaisedFor() async throws {
        let world = try await TestWorld.make()
        let badge = provider(world)
        await badge.refresh(space: world.space, viewer: world.me, partner: world.partner)
        #expect(badge.showsDot == false)

        _ = try await world.repositories.wishes.create(
            WishDraft(
                spaceId: world.space.id,
                ownerMemberId: world.partner.id,
                addedByMemberId: world.partner.id,
                title: "Apron"
            )
        )
        await badge.refresh(space: world.space, viewer: world.me, partner: world.partner)
        #expect(badge.showsDot)

        let visited = try await badge.markVisited(memberId: world.me.id)
        #expect(visited.lastUsVisitAt != nil)
        #expect(badge.showsDot == false)
    }

    @Test func openingTheHubLeavesAnUnansweredVoteAlone() async throws {
        let world = try await TestWorld.make()
        let badge = provider(world)
        _ = try await world.repositories.votes.create(
            VoteDraft(
                spaceId: world.space.id,
                question: "Where to eat",
                options: ["Sushi", "Pasta"],
                createdByMemberId: world.partner.id
            )
        )
        await badge.refresh(space: world.space, viewer: world.me, partner: world.partner)
        #expect(badge.showsDot)

        try await badge.markVisited(memberId: world.me.id)
        #expect(badge.showsDot)
    }

    @Test func todaysQuestionDotsThePillUntilTheViewerOpensIt() async throws {
        let world = try await TestWorld.make()
        let clock = Date(timeIntervalSince1970: 1_788_000_000)
        let badge = UsBadgeProvider(repositories: world.repositories, now: { clock })
        await badge.refresh(space: world.space, viewer: world.me, partner: world.partner)
        #expect(badge.showsDot == false)

        let question = try #require(
            try await world.repositories.questions.todaysQuestion(
                spaceId: world.space.id,
                viewerMemberId: world.me.id,
                now: clock
            )
        )
        await badge.refresh(space: world.space, viewer: world.me, partner: world.partner)
        #expect(badge.showsDot)

        let looked = try await world.repositories.questions.markSeen(
            memberId: world.me.id,
            dayKey: question.dayKey
        )
        await badge.refresh(space: world.space, viewer: looked, partner: world.partner)
        #expect(badge.showsDot == false)
    }

    @Test func signingOutDropsTheDot() async throws {
        let world = try await TestWorld.make()
        let badge = provider(world)
        _ = try await world.repositories.votes.create(
            VoteDraft(
                spaceId: world.space.id,
                question: "Where to eat",
                options: ["Sushi", "Pasta"],
                createdByMemberId: world.partner.id
            )
        )
        await badge.refresh(space: world.space, viewer: world.me, partner: world.partner)
        #expect(badge.showsDot)

        await badge.refresh(space: nil, viewer: nil, partner: nil)
        #expect(badge.showsDot == false)
    }
}
