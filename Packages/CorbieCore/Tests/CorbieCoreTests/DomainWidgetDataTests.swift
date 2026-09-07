import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainWidgetPremiumTests {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func space(status: SubscriptionStatus, trialEndsAt: Date?, expiresAt: Date?) -> SpaceDTO {
        SpaceDTO(
            id: UUID(),
            trialEndsAt: trialEndsAt,
            subscriptionStatus: status,
            subscriptionExpiresAt: expiresAt
        )
    }

    @Test func aLiveTrialUnlocksTheWidgets() {
        let subject = space(status: .trial, trialEndsAt: now.addingTimeInterval(3600), expiresAt: nil)
        #expect(WidgetPremiumRule.isPremium(space: subject, now: now))
    }

    @Test func anExpiredTrialWithoutASubscriptionLocksTheWidgets() {
        let subject = space(status: .expired, trialEndsAt: now.addingTimeInterval(-3600), expiresAt: nil)
        #expect(WidgetPremiumRule.isPremium(space: subject, now: now) == false)
    }

    @Test func anActiveSubscriptionUnlocksUntilItExpires() {
        let live = space(status: .active, trialEndsAt: nil, expiresAt: now.addingTimeInterval(86_400))
        #expect(WidgetPremiumRule.isPremium(space: live, now: now))
        let lapsed = space(status: .active, trialEndsAt: nil, expiresAt: now.addingTimeInterval(-1))
        #expect(WidgetPremiumRule.isPremium(space: lapsed, now: now) == false)
        let openEnded = space(status: .active, trialEndsAt: nil, expiresAt: nil)
        #expect(WidgetPremiumRule.isPremium(space: openEnded, now: now))
    }

    @Test func readOnlyAndNoneStayLocked() {
        for status in [SubscriptionStatus.none, .readonly, .expired] {
            let subject = space(status: status, trialEndsAt: nil, expiresAt: now.addingTimeInterval(86_400))
            #expect(WidgetPremiumRule.isPremium(space: subject, now: now) == false)
        }
    }

    @Test func amountsUseTheLocaleAndDropEmptyCents() {
        let american = Locale(identifier: "en_US")
        #expect(Money(amount: Double(2400), currency: "USD").formatted(locale: american) == "$2,400")
        #expect(Money(amount: Double(14.5), currency: "USD").formatted(locale: american) == "$14.50")
        let german = Money(amount: Double(2400), currency: "EUR").formatted(locale: Locale(identifier: "de_DE"))
        #expect(german.contains("2.400"))
    }
}

@Suite struct DomainWidgetDataProviderTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "Europe/Berlin")
    private let locale = Locale(identifier: "en_US")

    private struct World {
        let provider: WidgetDataProvider
        let seed: PreviewSeedResult
        let now: Date
    }

    private func makeWorld() async throws -> World {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let seed = try await PreviewSeed.make(now: now, calendar: calendar)
        let provider = WidgetDataProvider(
            controller: seed.controller,
            calendar: calendar,
            locale: locale,
            viewerMemberId: seed.me.id
        )
        return World(provider: provider, seed: seed, now: now)
    }

    @Test func theContextResolvesTheViewerAndThePartner() async throws {
        let world = try await makeWorld()
        let context = try #require(try await world.provider.context(now: world.now))
        #expect(context.viewer?.id == world.seed.me.id)
        #expect(context.partner?.id == world.seed.partner.id)
        #expect(context.isPremium)
        #expect(context.colorKey(for: world.seed.partner.id) == MemberColorSlot.partnerDefault.rawValue)
        #expect(context.name(for: world.seed.partner.id) == "Sofia")
    }

    @Test func daysTogetherComesFromTheSpace() async throws {
        let world = try await makeWorld()
        let snapshot = try await world.provider.daysTogether(now: world.now)
        #expect(snapshot.days == 460)
        #expect(snapshot.isPremium)
    }

    @Test func theTaskWidgetShowsThreeOpenTasksWithOwnership() async throws {
        let world = try await makeWorld()
        let snapshot = try await world.provider.tasks(now: world.now)
        #expect(snapshot.items.count == 3)
        #expect(snapshot.remaining == 1)
        #expect(snapshot.items[0].title == "Book the vet")
        #expect(snapshot.items[0].colorKey == MemberColorSlot.creatorDefault.rawValue)
        let free = snapshot.items.first { $0.title == "Buy milk" }
        #expect(free?.isFree == true)
        #expect(free?.colorKey == nil)
    }

    @Test func theFreeTaskWidgetOnlyShowsUnassignedWork() async throws {
        let world = try await makeWorld()
        let snapshot = try await world.provider.freeTasks(now: world.now)
        #expect(snapshot.items.map(\.title) == ["Buy milk"])
        #expect(snapshot.remaining == 0)
    }

    @Test func partnerWishesArePricedAndCounted() async throws {
        let world = try await makeWorld()
        let snapshot = try await world.provider.partnerWishes(now: world.now)
        #expect(snapshot.partnerName == "Sofia")
        #expect(snapshot.items.map(\.title) == ["Linen apron", "Chemex filters"])
        #expect(snapshot.items[0].priceText == "$48")
        #expect(snapshot.items[1].priceText == "$14.50")
        #expect(snapshot.remaining == 0)
    }

    @Test func planProgressReadsTheActivePlan() async throws {
        let world = try await makeWorld()
        let snapshot = try await world.provider.planProgress(now: world.now)
        #expect(snapshot.planId == world.seed.plan.id)
        #expect(snapshot.title == "Lisbon in October")
        #expect(snapshot.savedText == "$3,268.90")
        #expect(snapshot.targetText == "$5,000")
        #expect(abs(snapshot.progress - 0.65378) < 0.0001)
        #expect(snapshot.isOverspent == false)
    }

    @Test func planProgressCountsTheStepsOfThatPlan() async throws {
        let world = try await makeWorld()
        let repositories = world.seed.controller.repositories
        let steps = try await repositories.plans.steps(planId: world.seed.plan.id)
        _ = try await repositories.plans.toggleStep(
            stepId: try #require(steps.first).id,
            by: world.seed.me.id,
            at: world.now
        )
        let snapshot = try await world.provider.planProgress(now: world.now)
        #expect(snapshot.stepCount == 2)
        #expect(snapshot.doneStepCount == 1)
    }

    @Test func upcomingDatesMergeAutoDatesAndEvents() async throws {
        let world = try await makeWorld()
        let snapshot = try await world.provider.upcomingDates(now: world.now)
        #expect(snapshot.items.count == 3)
        #expect(snapshot.items[0].kind == .event)
        #expect(snapshot.items[0].title == "Dinner with Anna")
        #expect(snapshot.items[0].daysAway == 1)
        let ordered = snapshot.items.map(\.date)
        #expect(ordered == ordered.sorted())
    }

    @Test func upcomingDatesCarryTheRadarStatusInsideTheWindow() async throws {
        let world = try await makeWorld()
        let repositories = world.seed.controller.repositories
        var anna = try #require(try await repositories.people.people(spaceId: world.seed.space.id).first { $0.name == "Anna" })
        anna.birthdayMonth = 9
        anna.birthdayDay = 12
        _ = try await repositories.people.update(anna)
        let snapshot = try await world.provider.upcomingDates(now: world.now)
        let birthday = try #require(snapshot.items.first { $0.kind == .personBirthday })
        #expect(birthday.radar == RadarStatus(ideasCount: 2, giftPicked: false))
        #expect(birthday.title == "Anna")
    }

    @Test func aPersonDateReachesTheUpcomingWidget() async throws {
        let world = try await makeWorld()
        let repositories = world.seed.controller.repositories
        let anna = try #require(
            try await repositories.people.people(spaceId: world.seed.space.id).first { $0.name == "Anna" }
        )
        _ = try await repositories.people.addDate(
            personId: anna.id,
            draft: PersonDateDraft(title: "wedding day", month: 9, day: 8)
        )
        let snapshot = try await world.provider.upcomingDates(now: world.now)
        let date = try #require(snapshot.items.first { $0.kind == .event && $0.eventId == nil })
        #expect(date.title == "Anna: wedding day")
        #expect(date.daysAway == 3)
        #expect(date.radar == RadarStatus(ideasCount: 2, giftPicked: false))
        #expect(WidgetDateLabel.upcoming(kind: date.kind, title: date.title, locale: locale) == "Anna: wedding day")
    }

    @Test func aKnownBirthYearReachesTheWidgetAsAnOrdinal() async throws {
        let world = try await makeWorld()
        let repositories = world.seed.controller.repositories
        var anna = try #require(
            try await repositories.people.people(spaceId: world.seed.space.id).first { $0.name == "Anna" }
        )
        anna.birthdayMonth = 9
        anna.birthdayDay = 12
        anna.birthdayYear = 1992
        _ = try await repositories.people.update(anna)
        let snapshot = try await world.provider.upcomingDates(now: world.now)
        let birthday = try #require(snapshot.items.first { $0.kind == .personBirthday })
        #expect(birthday.ordinal == 34)
        #expect(
            WidgetDateLabel.upcoming(
                kind: birthday.kind,
                title: birthday.title,
                ordinal: birthday.ordinal,
                locale: locale
            ) == "Anna's 34th birthday"
        )
    }

    @Test func theShoppingWidgetReadsThePinnedList() async throws {
        let world = try await makeWorld()
        let snapshot = try await world.provider.shopping(now: world.now)
        #expect(snapshot.listId == world.seed.shoppingList.id)
        #expect(snapshot.items.map(\.title) == ["Milk", "Coffee", "Sourdough"])
        #expect(snapshot.items.allSatisfy { $0.isChecked == false })
        #expect(snapshot.remaining == 0)
    }

    @Test func checkedShoppingItemsLeaveTheWidget() async throws {
        let world = try await makeWorld()
        let repositories = world.seed.controller.repositories
        let items = try await repositories.lists.items(listId: world.seed.shoppingList.id)
        _ = try await repositories.lists.toggleItem(itemId: items[0].id, memberId: world.seed.me.id, at: world.now)
        let snapshot = try await world.provider.shopping(now: world.now)
        #expect(snapshot.items.map(\.title) == ["Coffee", "Sourdough"])
    }

    @Test func theCapsuleWidgetShowsTheNextSealedLetter() async throws {
        let world = try await makeWorld()
        let snapshot = try await world.provider.capsule(now: world.now)
        #expect(snapshot.capsuleId == world.seed.capsule.id)
        #expect(snapshot.authorName == "Sofia")
        #expect(snapshot.isForViewer)
        #expect(snapshot.daysAway == 186)
    }

    @Test func theCountdownWidgetResolvesEverySource() async throws {
        let world = try await makeWorld()
        let anniversary = try await world.provider.countdown(source: .anniversary, now: world.now)
        #expect(anniversary.kind == .anniversary)
        #expect(anniversary.ordinal == 2)
        #expect(anniversary.daysAway == 270)
        let wedding = try await world.provider.countdown(source: .wedding, now: world.now)
        #expect(wedding.kind == .wedding)
        #expect(wedding.ordinal == 1)
        let birthday = try await world.provider.countdown(source: .partnerBirthday, now: world.now)
        #expect(birthday.kind == .partnerBirthday)
        #expect(birthday.title == "Sofia")
        #expect(birthday.daysAway == 16)
        let eventId = try #require(world.seed.events.first?.id)
        let custom = try await world.provider.countdown(source: .customEvent(eventId), now: world.now)
        #expect(custom.kind == .customEvent)
        #expect(custom.title == "Dinner with Anna")
        #expect(custom.daysAway == 1)
    }

    @Test func ourDayShowsWhatTodayShows() async throws {
        let world = try await makeWorld()
        let snapshot = try await world.provider.ourDay(now: world.now)
        #expect(snapshot.days == 460)
        #expect(snapshot.tasks.map(\.title) == ["Book the vet"])
        #expect(snapshot.events.isEmpty)
        #expect(snapshot.plan?.id == world.seed.plan.id)
        #expect(snapshot.plan?.targetText == "$5,000")
        #expect(snapshot.isPremium)
    }

    @Test func ourDayIsTheTodayFeedCutToTheWidget() async throws {
        let world = try await makeWorld()
        let repositories = world.seed.controller.repositories
        let spaceId = world.seed.space.id
        for hour in ["16:00", "17:00", "18:00"] {
            _ = try await repositories.tasks.create(
                TaskDraft(
                    spaceId: spaceId,
                    title: "Task at " + hour,
                    assigneeMemberId: world.seed.me.id,
                    dueAt: DomainClock.date("2026-09-05 " + hour, in: calendar),
                    createdByMemberId: world.seed.me.id
                )
            )
            _ = try await repositories.events.create(
                EventDraft(
                    spaceId: spaceId,
                    title: "Event at " + hour,
                    startAt: DomainClock.date("2026-09-05 " + hour, in: calendar),
                    createdByMemberId: world.seed.partner.id
                )
            )
        }
        _ = try await repositories.plans.addStep(
            planId: world.seed.plan.id,
            draft: PlanStepDraft(title: "Print the tickets", dueAt: DomainClock.date("2026-09-05 19:00", in: calendar))
        )
        let feed = try await TodayFeedProvider(repositories: repositories, calendar: calendar, locale: locale)
            .feed(space: world.seed.space, viewerMemberId: world.seed.me.id, now: world.now)
        let snapshot = try await world.provider.ourDay(now: world.now)
        let lines = WidgetDataProvider.ourDayLineLimit
        #expect(feed.tasksToday.count > lines)
        #expect(feed.eventsToday.count > lines)
        #expect(snapshot.days == feed.daysTogether)
        #expect(snapshot.tasks.map(\.id) == feed.tasksToday.prefix(lines).map(\.id))
        #expect(snapshot.events.map(\.id) == feed.eventsToday.prefix(lines).map(\.id))
        #expect(snapshot.plan == feed.plans.first)
        #expect(feed.eventsToday.contains { $0.title == "Print the tickets" })
    }

    @Test func theTaskWidgetsLeavePlanStepsToToday() async throws {
        let world = try await makeWorld()
        _ = try await world.seed.controller.repositories.plans.addStep(
            planId: world.seed.plan.id,
            draft: PlanStepDraft(title: "Print the tickets", dueAt: DomainClock.date("2026-09-05 19:00", in: calendar))
        )
        let tasks = try await world.provider.tasks(now: world.now)
        #expect(tasks.items.contains { $0.title == "Print the tickets" } == false)
        let free = try await world.provider.freeTasks(now: world.now)
        #expect(free.items.map(\.title) == ["Buy milk"])
    }

    @Test func theLockScreenSnapshotsCoverEveryMode() async throws {
        let world = try await makeWorld()
        let days = try await world.provider.lockCircular(mode: .daysTogether, now: world.now)
        #expect(days.value == 460)
        let ring = try await world.provider.lockCircular(mode: .planRing, now: world.now)
        #expect(ring.value == 65)
        #expect(abs((ring.progress ?? 0) - 0.65378) < 0.0001)
        let countdown = try await world.provider.lockCircular(mode: .countdown, now: world.now)
        #expect(countdown.value == 1)
        let rectangular = try await world.provider.lockRectangular(now: world.now)
        #expect(rectangular.taskTitle == "Book the vet")
        #expect(rectangular.freeCount == 1)
        #expect(rectangular.nextDate?.title == "Dinner with Anna")
        let inline = try await world.provider.lockInline(now: world.now)
        #expect(inline.kind == .event)
        #expect(inline.name == "Dinner with Anna")
        #expect(inline.daysAway == 1)
    }

    @Test func anEmptyStoreProducesLockedEmptySnapshots() async throws {
        let controller = PersistenceController.inMemory()
        let provider = WidgetDataProvider(controller: controller, calendar: calendar, locale: locale)
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        #expect(try await provider.context(now: now) == nil)
        #expect(try await provider.daysTogether(now: now) == DaysTogetherSnapshot(days: nil, isPremium: false))
        #expect(try await provider.tasks(now: now).items.isEmpty)
        #expect(try await provider.freeTasks(now: now).isPremium == false)
        #expect(try await provider.partnerWishes(now: now).items.isEmpty)
        #expect(try await provider.planProgress(now: now).planId == nil)
        #expect(try await provider.upcomingDates(now: now).items.isEmpty)
        #expect(try await provider.shopping(now: now).listId == nil)
        #expect(try await provider.capsule(now: now).capsuleId == nil)
        #expect(try await provider.ourDay(now: now).days == nil)
        #expect(try await provider.freeSlots(now: now).availability == .notPaired)
        #expect(try await provider.lockCircular(mode: .planRing, now: now).value == nil)
        #expect(try await provider.lockRectangular(now: now).taskTitle == nil)
        #expect(try await provider.lockInline(now: now).kind == nil)
    }

    @Test func anExpiredSpaceLocksEverySnapshot() async throws {
        let world = try await makeWorld()
        var space = world.seed.space
        space.trialEndsAt = DomainClock.date("2026-08-01", in: calendar)
        space.subscriptionStatus = .expired
        _ = try await world.seed.controller.repositories.spaces.update(space)
        #expect(try await world.provider.tasks(now: world.now).isPremium == false)
        #expect(try await world.provider.daysTogether(now: world.now).isPremium == false)
        #expect(try await world.provider.ourDay(now: world.now).isPremium == false)
    }
}

@Suite struct DomainWidgetFreeSlotsTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "Europe/Berlin")
    private let locale = Locale(identifier: "en_US")

    private struct World {
        let provider: WidgetDataProvider
        let seed: PreviewSeedResult
        let now: Date
    }

    private func makeWorld() async throws -> World {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let seed = try await PreviewSeed.make(now: now, calendar: calendar)
        let provider = WidgetDataProvider(
            controller: seed.controller,
            calendar: calendar,
            locale: locale,
            viewerMemberId: seed.me.id
        )
        return World(provider: provider, seed: seed, now: now)
    }

    private func spaced(_ text: String?) -> String? {
        text?
            .replacingOccurrences(of: "\u{202F}", with: " ")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private func share(_ world: World, viewer: Bool, partner: Bool) async throws {
        let members = world.seed.controller.repositories.members
        _ = try await members.setSharesBusyTimes(memberId: world.seed.me.id, shares: viewer)
        _ = try await members.setSharesBusyTimes(memberId: world.seed.partner.id, shares: partner)
    }

    private func fill(_ world: World, memberId: UUID, days: Int, from startHour: Int, to endHour: Int) async throws {
        let drafts: [BusyIntervalDraft] = (0 ..< days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: world.now),
                  let start = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: day),
                  let end = calendar.date(bySettingHour: endHour, minute: 0, second: 0, of: day)
            else { return nil }
            return BusyIntervalDraft(startAt: start, endAt: end)
        }
        _ = try await world.seed.controller.repositories.busyIntervals.replace(
            spaceId: world.seed.space.id,
            memberId: memberId,
            source: .device,
            intervals: drafts,
            at: world.now
        )
    }

    @Test func nobodySharesUntilTheViewerTurnsItOn() async throws {
        let world = try await makeWorld()
        let snapshot = try await world.provider.freeSlots(now: world.now)
        #expect(snapshot.availability == .viewerNotSharing)
        #expect(snapshot.slots.isEmpty)
        #expect(snapshot.isPremium)
    }

    @Test func aPartnerWhoHasNotSharedGetsItsOwnState() async throws {
        let world = try await makeWorld()
        try await share(world, viewer: true, partner: false)
        let snapshot = try await world.provider.freeSlots(now: world.now)
        #expect(snapshot.availability == .partnerNotSharing)
        #expect(snapshot.slots.isEmpty)
    }

    @Test func theWidgetShowsTheNextTwoSharedWindows() async throws {
        let world = try await makeWorld()
        try await share(world, viewer: true, partner: true)
        try await fill(world, memberId: world.seed.me.id, days: 5, from: 8, to: 18)
        try await fill(world, memberId: world.seed.partner.id, days: 5, from: 8, to: 17)
        let snapshot = try await world.provider.freeSlots(now: world.now)
        #expect(snapshot.availability == .slots)
        #expect(snapshot.slots.count == WidgetDataProvider.freeSlotLimit)
        #expect(
            snapshot.slots.map(\.start) == [
                DomainClock.date("2026-09-05 18:00", in: calendar),
                DomainClock.date("2026-09-06 18:00", in: calendar)
            ]
        )
        #expect(snapshot.slots.map(\.dayText) == ["Sat, Sep 5", "Sun, Sep 6"])
        #expect(snapshot.slots.map { spaced($0.windowText) } == ["after 6:00 PM", "after 6:00 PM"])
    }

    @Test func aFullFortnightLeavesNoWindow() async throws {
        let world = try await makeWorld()
        try await share(world, viewer: true, partner: true)
        try await fill(world, memberId: world.seed.me.id, days: 16, from: 0, to: 23)
        let snapshot = try await world.provider.freeSlots(now: world.now)
        #expect(snapshot.availability == .noSlots)
        #expect(snapshot.slots.isEmpty)
    }

    @Test func aWindowThatEndsBeforeTheEveningKeepsBothEnds() async throws {
        let world = try await makeWorld()
        try await share(world, viewer: true, partner: true)
        _ = try await world.seed.controller.repositories.busyIntervals.replace(
            spaceId: world.seed.space.id,
            memberId: world.seed.me.id,
            source: .device,
            intervals: [
                BusyIntervalDraft(
                    startAt: DomainClock.date("2026-09-05 00:00", in: calendar),
                    endAt: DomainClock.date("2026-09-05 14:00", in: calendar)
                ),
                BusyIntervalDraft(
                    startAt: DomainClock.date("2026-09-05 16:00", in: calendar),
                    endAt: DomainClock.date("2026-09-09 23:00", in: calendar)
                )
            ],
            at: world.now
        )
        let snapshot = try await world.provider.freeSlots(now: world.now)
        #expect(spaced(snapshot.slots.first?.windowText) == "2:00 PM - 4:00 PM")
    }

    @Test func aLockedSpaceStillReportsTheState() async throws {
        let world = try await makeWorld()
        try await share(world, viewer: true, partner: true)
        var space = world.seed.space
        space.trialEndsAt = DomainClock.date("2026-08-01", in: calendar)
        space.subscriptionStatus = .expired
        _ = try await world.seed.controller.repositories.spaces.update(space)
        let snapshot = try await world.provider.freeSlots(now: world.now)
        #expect(snapshot.isPremium == false)
    }
}
