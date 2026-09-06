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
        #expect(context.colorKey(for: world.seed.partner.id) == MemberColorKey.p2.rawValue)
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
        #expect(snapshot.items[0].colorKey == MemberColorKey.p1.rawValue)
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
        #expect(snapshot.savedText == "$2,400")
        #expect(snapshot.targetText == "$5,000")
        #expect(abs(snapshot.progress - 0.48) < 0.0001)
        #expect(snapshot.isOverspent == false)
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

    @Test func ourDayComposesTheOtherWidgets() async throws {
        let world = try await makeWorld()
        let snapshot = try await world.provider.ourDay(now: world.now)
        #expect(snapshot.days == 460)
        #expect(snapshot.nextDate?.title == "Dinner with Anna")
        #expect(snapshot.plan?.planId == world.seed.plan.id)
        #expect(snapshot.tasks.count == 3)
        #expect(snapshot.isPremium)
    }

    @Test func theLockScreenSnapshotsCoverEveryMode() async throws {
        let world = try await makeWorld()
        let days = try await world.provider.lockCircular(mode: .daysTogether, now: world.now)
        #expect(days.value == 460)
        let ring = try await world.provider.lockCircular(mode: .planRing, now: world.now)
        #expect(ring.value == 48)
        #expect(abs((ring.progress ?? 0) - 0.48) < 0.0001)
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
