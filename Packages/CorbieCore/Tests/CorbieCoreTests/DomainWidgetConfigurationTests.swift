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

    @Test func aCountdownConfiguredForAnEventThatIsNotChosenHasNoSource() {
        let unchosen = CountdownConfigurationIntent(source: .customEvent, event: nil)
        #expect(unchosen.countdownSource == nil)
        let eventId = UUID()
        let chosen = CountdownConfigurationIntent(
            source: .customEvent,
            event: CorbieEventEntity(id: eventId, title: "Dinner with Anna", date: nil)
        )
        #expect(chosen.countdownSource == .customEvent(eventId))
        #expect(CountdownConfigurationIntent(source: .wedding).countdownSource == .wedding)
    }

    @Test func theCountdownSourceSurvivesEncoding() throws {
        let eventId = UUID()
        let sources: [CountdownSource] = [.anniversary, .wedding, .partnerBirthday, .customEvent(eventId)]
        for source in sources {
            let data = try JSONEncoder().encode(source)
            #expect(try JSONDecoder().decode(CountdownSource.self, from: data) == source)
        }
    }

    @Test func aChosenGoalWinsOverTheNewestOne() async throws {
        let world = try await makeWorld()
        let second = try await world.seed.controller.repositories.goals.create(
            GoalDraft(
                spaceId: world.seed.space.id,
                title: "Kitchen",
                type: .renovation,
                targetAmount: 8000,
                currency: "USD",
                savedAmount: 1000,
                createdByMemberId: world.seed.me.id
            )
        )
        let chosen = try await world.provider.goalProgress(goalId: second.id, now: world.now)
        #expect(chosen.goalId == second.id)
        #expect(chosen.title == "Kitchen")
        let fallback = try await world.provider.goalProgress(goalId: nil, now: world.now)
        #expect(fallback.goalId == second.id)
    }

    @Test func aGoalThatIsGoneFallsBackToTheNewestOne() async throws {
        let world = try await makeWorld()
        let snapshot = try await world.provider.goalProgress(goalId: UUID(), now: world.now)
        #expect(snapshot.goalId == world.seed.goal.id)
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

    @Test func theGoalQueryOffersGoalsAndResolvesThemById() async throws {
        let world = try await makeWorld()
        let options = try await world.provider.selectableGoals(now: world.now)
        #expect(options.map(\.id) == [world.seed.goal.id])
        let resolved = try await world.provider.goalOptions(ids: [world.seed.goal.id, UUID()])
        #expect(resolved.map(\.title) == ["Lisbon in October"])
        #expect(abs((resolved.first?.progress ?? 0) - 0.65378) < 0.0001)
    }

    @Test func theShoppingWidgetCountsWhatItCannotShow() async throws {
        let world = try await makeWorld()
        let repositories = world.seed.controller.repositories
        for title in ["Butter", "Eggs"] {
            _ = try await repositories.tasks.create(
                TaskDraft(
                    spaceId: world.seed.space.id,
                    title: title,
                    folderId: world.seed.shoppingFolder.id,
                    createdByMemberId: world.seed.me.id
                )
            )
        }
        let snapshot = try await world.provider.shopping(now: world.now)
        #expect(snapshot.items.count == WidgetDataProvider.shoppingLimit)
        #expect(snapshot.remaining == 2)
    }
}
