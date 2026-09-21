import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct QuestionStatusTests {
    private let today = "2026-09-21"
    private let yesterday = "2026-09-20"

    private func status(
        day: String? = nil,
        viewerAnswered: Bool,
        partnerAnswered: Bool,
        read: [String] = []
    ) -> QuestionStatus {
        QuestionStatus(
            dayKey: day ?? today,
            todayKey: today,
            viewerAnswered: viewerAnswered,
            partnerAnswered: partnerAnswered,
            readDays: RevealReadDays(read)
        )
    }

    @Test func theFourStatesFollowWhoAnsweredAndWhetherTheRevealWasOpened() {
        let neither = status(viewerAnswered: false, partnerAnswered: false)
        #expect(neither.progress == .unanswered(partnerAnswered: false))
        #expect(neither.progress.isCompact == false)
        #expect(neither.showsTodayDot == false)

        let partnerFirst = status(viewerAnswered: false, partnerAnswered: true)
        #expect(partnerFirst.progress == .unanswered(partnerAnswered: true))
        #expect(partnerFirst.progress.isCompact == false)
        #expect(partnerFirst.showsTodayDot == false)

        let waiting = status(viewerAnswered: true, partnerAnswered: false)
        #expect(waiting.progress == .waitingForPartner)
        #expect(waiting.progress.isCompact)
        #expect(waiting.showsTodayDot == false)

        let unread = status(viewerAnswered: true, partnerAnswered: true)
        #expect(unread.progress == .revealUnread)
        #expect(unread.progress.isCompact)
        #expect(unread.showsTodayDot)
        #expect(unread.showsHistoryDot == false)

        let read = status(viewerAnswered: true, partnerAnswered: true, read: [today])
        #expect(read.progress == .revealRead)
        #expect(read.progress.isCompact)
        #expect(read.showsTodayDot == false)
    }

    @Test func aNewDayStartsOverWhateverWasReadBefore() {
        let tomorrow = QuestionStatus(
            dayKey: "2026-09-22",
            todayKey: "2026-09-22",
            viewerAnswered: false,
            partnerAnswered: false,
            readDays: RevealReadDays([today])
        )
        #expect(tomorrow.progress == .unanswered(partnerAnswered: false))
        #expect(tomorrow.showsTodayDot == false)
    }

    @Test func aPastRevealLeftUnreadDotsTheHistoryAndNotToday() {
        let missed = status(day: yesterday, viewerAnswered: true, partnerAnswered: true, read: ["2026-09-18"])
        #expect(missed.progress == .revealUnread)
        #expect(missed.showsHistoryDot)
        #expect(missed.showsTodayDot == false)

        let opened = status(day: yesterday, viewerAnswered: true, partnerAnswered: true, read: ["2026-09-18", yesterday])
        #expect(opened.showsHistoryDot == false)

        let neverRevealed = status(day: yesterday, viewerAnswered: true, partnerAnswered: false, read: ["2026-09-18"])
        #expect(neverRevealed.showsHistoryDot == false)
    }

    @Test func daysBeforeTheListStartsCountAsRead() {
        let beforeTracking = status(day: "2026-09-10", viewerAnswered: true, partnerAnswered: true, read: ["2026-09-18"])
        #expect(beforeTracking.progress == .revealRead)
        #expect(beforeTracking.showsHistoryDot == false)

        let nothingReadYet = status(day: yesterday, viewerAnswered: true, partnerAnswered: true)
        #expect(nothingReadYet.showsHistoryDot == false)
        #expect(status(viewerAnswered: true, partnerAnswered: true).showsTodayDot)
    }

    @Test func theListKeepsAYearAndSkipsDaysItAlreadyCountsAsRead() {
        let start = RevealReadDays(["2026-09-18"])
        #expect(start.adding("2026-09-10") == start)
        #expect(start.adding("2026-09-18") == start)
        #expect(start.adding(yesterday).dayKeys == ["2026-09-18", yesterday])

        let first = DomainClock.date("2025-01-01", in: DomainClock.calendar())
        let keys = (0..<(RevealReadDays.limit + 10)).map { offset in
            QuestionSelector.dayKey(for: first.addingTimeInterval(Double(offset) * 86_400), timeZone: .gmt)
        }
        let full = RevealReadDays(Array(keys.reversed()))
        #expect(full.dayKeys.count == RevealReadDays.limit)
        #expect(full.dayKeys.first == keys[10])
        #expect(full.dayKeys.last == keys.last)
        #expect(full.hasRead(keys[3], today: keys.last ?? ""))
    }

    @Test func theStoredFormIsAPlainSortedListOfDays() throws {
        let data = try JSONEncoder().encode(RevealReadDays([today, yesterday, today]))
        #expect(String(decoding: data, as: UTF8.self) == "[\"2026-09-20\",\"2026-09-21\"]")
        #expect(try JSONDecoder().decode(RevealReadDays.self, from: data).dayKeys == [yesterday, today])
    }
}

@Suite struct QuestionReadFlowTests {
    private let now = Date(timeIntervalSince1970: 1_788_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    private func todaysStatus(_ world: TestWorld, at date: Date) async throws -> QuestionStatus {
        let question = try #require(
            try await world.repositories.questions.todaysQuestion(
                spaceId: world.space.id,
                viewerMemberId: world.me.id,
                now: date
            )
        )
        return try await status(of: question, world: world, at: date)
    }

    private func status(of question: DailyQuestionDTO, world: TestWorld, at date: Date) async throws -> QuestionStatus {
        let viewer = try await world.repositories.members.member(id: world.me.id)
        return QuestionStatus(
            question: question,
            todayKey: QuestionStatus.todayKey(now: date, space: world.space),
            viewer: viewer,
            partnerId: world.partner.id
        )
    }

    private func answer(_ question: DailyQuestionDTO, by memberId: UUID, in world: TestWorld, at date: Date) async throws {
        _ = try await world.repositories.questions.answer(
            dailyQuestionId: question.id,
            memberId: memberId,
            text: "A dog on the tram",
            at: date
        )
    }

    @Test func answeringThenThePartnerThenOpeningTheRevealWalksTheFourStates() async throws {
        let world = try await TestWorld.make()
        let questions = world.repositories.questions
        let question = try #require(
            try await questions.todaysQuestion(spaceId: world.space.id, viewerMemberId: world.me.id, now: now)
        )
        #expect(try await todaysStatus(world, at: now).progress == .unanswered(partnerAnswered: false))

        try await answer(question, by: world.me.id, in: world, at: now)
        #expect(try await todaysStatus(world, at: now).progress == .waitingForPartner)

        try await answer(question, by: world.partner.id, in: world, at: now)
        let revealed = try await todaysStatus(world, at: now)
        #expect(revealed.progress == .revealUnread)
        #expect(revealed.showsTodayDot)

        let reader = try await questions.markRevealRead(memberId: world.me.id, dayKey: question.dayKey)
        #expect(reader.revealReadDays.dayKeys == [question.dayKey])
        let read = try await todaysStatus(world, at: now)
        #expect(read.progress == .revealRead)
        #expect(read.showsTodayDot == false)

        let tomorrow = try await todaysStatus(world, at: now.addingTimeInterval(day))
        #expect(tomorrow.progress == .unanswered(partnerAnswered: false))
        #expect(tomorrow.showsTodayDot == false)
    }

    @Test func onlyThePartnerHavingAnsweredKeepsTheFullCard() async throws {
        let world = try await TestWorld.make()
        let question = try #require(
            try await world.repositories.questions.todaysQuestion(
                spaceId: world.space.id,
                viewerMemberId: world.me.id,
                now: now
            )
        )
        try await answer(question, by: world.partner.id, in: world, at: now)
        let status = try await todaysStatus(world, at: now)
        #expect(status.progress == .unanswered(partnerAnswered: true))
        #expect(status.progress.isCompact == false)
        #expect(status.showsTodayDot == false)
    }

    @MainActor
    @Test func lookingAtTodayDoesNotMarkTheRevealRead() async throws {
        let world = try await TestWorld.make()
        let questions = world.repositories.questions
        let question = try #require(
            try await questions.todaysQuestion(spaceId: world.space.id, viewerMemberId: world.me.id, now: now)
        )
        try await answer(question, by: world.me.id, in: world, at: now)
        try await answer(question, by: world.partner.id, in: world, at: now)

        _ = try await questions.todaysQuestion(spaceId: world.space.id, viewerMemberId: world.me.id, now: now)
        _ = try await questions.storedQuestion(spaceId: world.space.id, viewerMemberId: world.me.id, now: now)
        _ = try await questions.markSeen(memberId: world.me.id, dayKey: question.dayKey)
        let widgets = WidgetDataProvider(
            controller: world.controller,
            viewerMemberId: world.me.id,
            monetization: MonetizationTestSupport.enabled
        )
        _ = try await widgets.question(now: now)
        let badge = UsBadgeProvider(repositories: world.repositories, now: { [now] in now })
        await badge.refresh(space: world.space, viewer: world.me, partner: world.partner)

        let viewer = try #require(try await world.repositories.members.member(id: world.me.id))
        #expect(viewer.revealReadDays.dayKeys.isEmpty)
        #expect(try await todaysStatus(world, at: now).progress == .revealUnread)
    }

    @Test func aMissedRevealFromAPastDayDotsItsHistoryRowAndNotToday() async throws {
        let world = try await TestWorld.make()
        let questions = world.repositories.questions
        let dayOne = now
        let dayTwo = now.addingTimeInterval(day)
        let dayThree = now.addingTimeInterval(2 * day)

        let first = try #require(
            try await questions.todaysQuestion(spaceId: world.space.id, viewerMemberId: world.me.id, now: dayOne)
        )
        try await answer(first, by: world.me.id, in: world, at: dayOne)
        try await answer(first, by: world.partner.id, in: world, at: dayOne)
        _ = try await questions.markRevealRead(memberId: world.me.id, dayKey: first.dayKey)

        let second = try #require(
            try await questions.todaysQuestion(spaceId: world.space.id, viewerMemberId: world.me.id, now: dayTwo)
        )
        try await answer(second, by: world.me.id, in: world, at: dayTwo)
        try await answer(second, by: world.partner.id, in: world, at: dayTwo)

        let today = try await todaysStatus(world, at: dayThree)
        #expect(today.showsTodayDot == false)

        let history = try await questions.history(spaceId: world.space.id, viewerMemberId: world.me.id)
        let missed = try #require(history.first { $0.id == second.id })
        let missedStatus = try await status(of: missed, world: world, at: dayThree)
        #expect(missedStatus.showsHistoryDot)
        #expect(missedStatus.showsTodayDot == false)

        let opened = try #require(history.first { $0.id == first.id })
        #expect(try await status(of: opened, world: world, at: dayThree).showsHistoryDot == false)

        _ = try await questions.markRevealRead(memberId: world.me.id, dayKey: missed.dayKey)
        #expect(try await status(of: missed, world: world, at: dayThree).showsHistoryDot == false)
    }

    @Test func theWidgetSnapshotCarriesTheSameStatusAsTheCard() async throws {
        let world = try await TestWorld.make()
        let questions = world.repositories.questions
        let widgets = WidgetDataProvider(
            controller: world.controller,
            viewerMemberId: world.me.id,
            monetization: MonetizationTestSupport.enabled
        )
        let question = try #require(
            try await questions.todaysQuestion(spaceId: world.space.id, viewerMemberId: world.me.id, now: now)
        )

        #expect(try await widgetAgrees(widgets, world: world) == .unanswered(partnerAnswered: false))
        try await answer(question, by: world.me.id, in: world, at: now)
        #expect(try await widgetAgrees(widgets, world: world) == .waitingForPartner)
        try await answer(question, by: world.partner.id, in: world, at: now)
        #expect(try await widgetAgrees(widgets, world: world) == .revealUnread)
        _ = try await questions.markRevealRead(memberId: world.me.id, dayKey: question.dayKey)
        #expect(try await widgetAgrees(widgets, world: world) == .revealRead)
    }

    private func widgetAgrees(_ widgets: WidgetDataProvider, world: TestWorld) async throws -> QuestionProgress {
        let card = try await todaysStatus(world, at: now)
        let snapshot = try await widgets.question(now: now)
        #expect(snapshot.status == card)
        return card.progress
    }
}

@Suite struct QuestionRevealBadgeTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "Europe/Berlin")
    private let viewerId = UUID()
    private let partnerId = UUID()

    private func lightsBadge(
        dayKey: String = "2026-09-21",
        viewerAnswered: Bool,
        partnerAnswered: Bool,
        read: [String] = []
    ) -> Bool {
        let now = DomainClock.date("2026-09-21 12:00", in: calendar)
        var answers: [QuestionAnswerDTO] = []
        if viewerAnswered {
            answers.append(QuestionAnswerDTO(id: UUID(), memberId: viewerId, text: "A dog on the tram"))
        }
        if partnerAnswered {
            answers.append(QuestionAnswerDTO(id: UUID(), memberId: partnerId, text: "The rain"))
        }
        let input = UsBadgeInput(
            space: SpaceDTO(id: UUID(), anchorTimeZone: "Europe/Berlin", memberCount: 2),
            viewer: MemberDTO(
                id: viewerId,
                displayName: "Ilya",
                lastUsVisitAt: now,
                lastQuestionSeenDayKey: "2026-09-21",
                revealReadDays: RevealReadDays(read)
            ),
            partner: MemberDTO(id: partnerId, displayName: "Sofia"),
            question: DailyQuestionDTO(
                id: UUID(),
                dayKey: dayKey,
                answers: answers,
                isRevealed: viewerAnswered && partnerAnswered
            )
        )
        return UsBadgeRule(calendar: calendar).showsDot(input, now: now)
    }

    @Test func amongTheQuestionStatesOnlyAnUnreadRevealLightsTheBadge() {
        #expect(lightsBadge(viewerAnswered: false, partnerAnswered: false) == false)
        #expect(lightsBadge(viewerAnswered: false, partnerAnswered: true) == false)
        #expect(lightsBadge(viewerAnswered: true, partnerAnswered: false) == false)
        #expect(lightsBadge(viewerAnswered: true, partnerAnswered: true))
        #expect(lightsBadge(viewerAnswered: true, partnerAnswered: true, read: ["2026-09-21"]) == false)
    }

    @Test func aRevealFromAnotherDayDoesNotLightTheBadge() {
        #expect(lightsBadge(dayKey: "2026-09-20", viewerAnswered: true, partnerAnswered: true, read: ["2026-09-19"]) == false)
    }

    @MainActor
    @Test func theBadgeFollowsTheRevealFromWaitingToRead() async throws {
        let world = try await TestWorld.make()
        let clock = Date(timeIntervalSince1970: 1_788_000_000)
        let questions = world.repositories.questions
        let badge = UsBadgeProvider(repositories: world.repositories, now: { clock })
        let question = try #require(
            try await questions.todaysQuestion(spaceId: world.space.id, viewerMemberId: world.me.id, now: clock)
        )
        let looked = try await questions.markSeen(memberId: world.me.id, dayKey: question.dayKey)
        await badge.refresh(space: world.space, viewer: looked, partner: world.partner)
        #expect(badge.showsDot == false)

        _ = try await questions.answer(dailyQuestionId: question.id, memberId: world.me.id, text: "Tea", at: clock)
        await badge.refresh(space: world.space, viewer: looked, partner: world.partner)
        #expect(badge.showsDot == false)

        _ = try await questions.answer(dailyQuestionId: question.id, memberId: world.partner.id, text: "Rain", at: clock)
        await badge.refresh(space: world.space, viewer: looked, partner: world.partner)
        #expect(badge.showsDot)

        let reader = try await questions.markRevealRead(memberId: world.me.id, dayKey: question.dayKey)
        await badge.refresh(space: world.space, viewer: reader, partner: world.partner)
        #expect(badge.showsDot == false)
    }
}

@Suite struct QuestionRevealReadStorageTests {
    private let dayKey = "2026-09-21"

    @Test func markingTheRevealReadWritesOnlyThatFieldAndKeepsANameChangedMeanwhile() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = PersistenceController(stack: CoreDataStack(storesIn: directory))
        let stale = try await makeMember(in: controller)
        #expect(stale.displayName == "Ilya")

        try rename(stale.id, to: "Ilya V", in: controller.stack)
        let before = controller.stack.container.persistentStoreCoordinator.currentPersistentHistoryToken(fromStores: nil)
        let marked = try await controller.repositories.questions.markRevealRead(memberId: stale.id, dayKey: dayKey)
        #expect(marked.displayName == "Ilya V")

        let stored = try #require(try await controller.repositories.members.member(id: stale.id))
        #expect(stored.displayName == "Ilya V")
        #expect(stored.revealReadDays.dayKeys == [dayKey])
        #expect(try memberUpdates(after: before, in: controller.stack) == [["revealReadDayKeysData"]])
    }

    @Test func markingADayAlreadyReadWritesNothing() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = PersistenceController(stack: CoreDataStack(storesIn: directory))
        let member = try await makeMember(in: controller)
        _ = try await controller.repositories.questions.markRevealRead(memberId: member.id, dayKey: dayKey)

        let before = controller.stack.container.persistentStoreCoordinator.currentPersistentHistoryToken(fromStores: nil)
        _ = try await controller.repositories.questions.markRevealRead(memberId: member.id, dayKey: dayKey)
        #expect(try memberUpdates(after: before, in: controller.stack).isEmpty)
    }

    @Test func theReadStateSurvivesARelaunch() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let memberId: UUID
        do {
            let controller = PersistenceController(stack: CoreDataStack(storesIn: directory))
            memberId = try await makeMember(in: controller).id
            _ = try await controller.repositories.questions.markRevealRead(memberId: memberId, dayKey: dayKey)
        }
        let relaunched = PersistenceController(stack: CoreDataStack(storesIn: directory))
        let stored = try #require(try await relaunched.repositories.members.member(id: memberId))
        #expect(stored.revealReadDays.dayKeys == [dayKey])
    }

    private func makeDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-reveal-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func makeMember(in controller: PersistenceController) async throws -> MemberDTO {
        let space = try await controller.repositories.spaces.create(displayCurrency: "USD")
        return try await controller.repositories.members.upsertCurrentMember(
            appleUserId: "apple-me",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Ilya", colorKey: MemberColorSlot.creatorDefault.rawValue),
            theme: .sand
        ).member
    }

    private func rename(_ memberId: UUID, to name: String, in stack: CoreDataStack) throws {
        let context = stack.newBackgroundContext()
        try context.performAndWait {
            let member: Member = try ManagedFetch.require(Member.entityName, id: memberId, in: context)
            member.displayName = name
            try context.save()
        }
    }

    private func memberUpdates(after token: NSPersistentHistoryToken?, in stack: CoreDataStack) throws -> [Set<String>] {
        let context = stack.newBackgroundContext()
        return try context.performAndWait {
            let result = try context.execute(NSPersistentHistoryChangeRequest.fetchHistory(after: token))
            let transactions = (result as? NSPersistentHistoryResult)?.result as? [NSPersistentHistoryTransaction] ?? []
            return transactions
                .flatMap { $0.changes ?? [] }
                .filter { $0.changedObjectID.entity.name == Member.entityName }
                .map { Set(($0.updatedProperties ?? []).map(\.name)) }
        }
    }
}
