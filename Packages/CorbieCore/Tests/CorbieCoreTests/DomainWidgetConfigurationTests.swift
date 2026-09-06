import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainWidgetConfigurationTests {
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

    @Test func aCountdownOnADeletedEventKeepsItsKindAndLosesItsDate() async throws {
        let world = try await makeWorld()
        let snapshot = try await world.provider.countdown(source: .customEvent(UUID()), now: world.now)
        #expect(snapshot.kind == .customEvent)
        #expect(snapshot.date == nil)
        #expect(snapshot.daysAway == nil)
        #expect(snapshot.title == nil)
    }

    @Test func aCountdownWithoutAWeddingDateHasNothingToCountTo() async throws {
        let world = try await makeWorld()
        var space = world.seed.space
        space.weddingDate = nil
        _ = try await world.seed.controller.repositories.spaces.update(space)
        let snapshot = try await world.provider.countdown(source: .wedding, now: world.now)
        #expect(snapshot.kind == .wedding)
        #expect(snapshot.date == nil)
    }

    @Test func theCountdownSourceSurvivesEncoding() throws {
        let eventId = UUID()
        let sources: [CountdownSource] = [.anniversary, .wedding, .partnerBirthday, .customEvent(eventId)]
        for source in sources {
            let data = try JSONEncoder().encode(source)
            #expect(try JSONDecoder().decode(CountdownSource.self, from: data) == source)
        }
    }

    @Test func aChosenPlanWinsOverTheNewestOne() async throws {
        let world = try await makeWorld()
        let second = try await world.seed.controller.repositories.plans.create(
            PlanDraft(
                spaceId: world.seed.space.id,
                title: "Kitchen",
                type: .renovation,
                targetAmount: 8000,
                currency: "USD",
                savedAmount: 1000,
                createdByMemberId: world.seed.me.id
            )
        )
        let chosen = try await world.provider.planProgress(planId: second.id, now: world.now)
        #expect(chosen.planId == second.id)
        #expect(chosen.title == "Kitchen")
        let fallback = try await world.provider.planProgress(planId: nil, now: world.now)
        #expect(fallback.planId == second.id)
    }

    @Test func aPlanThatIsGoneFallsBackToTheNewestOne() async throws {
        let world = try await makeWorld()
        let snapshot = try await world.provider.planProgress(planId: UUID(), now: world.now)
        #expect(snapshot.planId == world.seed.plan.id)
    }

    @Test func theEventQueryOffersUpcomingEventsAndResolvesThemById() async throws {
        let world = try await makeWorld()
        let options = try await world.provider.selectableEvents(now: world.now)
        #expect(options.isEmpty == false)
        #expect(options.map(\.title).contains("Dinner with Anna"))
        let first = try #require(options.first)
        let resolved = try await world.provider.eventOptions(ids: [first.id, UUID()], now: world.now)
        #expect(resolved.map(\.id) == [first.id])
    }

    @Test func thePlanQueryOffersPlansAndResolvesThemById() async throws {
        let world = try await makeWorld()
        let options = try await world.provider.selectablePlans(now: world.now)
        #expect(options.map(\.id) == [world.seed.plan.id])
        let resolved = try await world.provider.planOptions(ids: [world.seed.plan.id, UUID()])
        #expect(resolved.map(\.title) == ["Lisbon in October"])
        #expect(abs((resolved.first?.progress ?? 0) - 0.48) < 0.0001)
    }

    @Test func theShoppingWidgetCountsWhatItCannotShow() async throws {
        let world = try await makeWorld()
        let repositories = world.seed.controller.repositories
        for title in ["Butter", "Eggs"] {
            _ = try await repositories.lists.addItem(
                listId: world.seed.shoppingList.id,
                draft: ListItemDraft(title: title, addedByMemberId: world.seed.me.id)
            )
        }
        let snapshot = try await world.provider.shopping(now: world.now)
        #expect(snapshot.items.count == WidgetDataProvider.shoppingLimit)
        #expect(snapshot.remaining == 2)
    }
}
