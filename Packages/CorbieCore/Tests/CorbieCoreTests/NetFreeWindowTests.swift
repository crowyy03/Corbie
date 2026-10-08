import Foundation
import Testing
@testable import CorbieCore

@Suite struct NetFreeWindowTests {
    private let calendar = DomainClock.calendar()
    private let createdAt = NetTestSupport.date("2026-09-20T10:00:00Z")

    @Test func threeDaysFromTheSpaceRunToTheEndOfTheThirdDayAfter() throws {
        let window = try #require(FreeWindow(spaceCreatedAt: createdAt, days: 3, calendar: calendar))
        #expect(window.endsAt == NetTestSupport.date("2026-09-24T00:00:00Z"))
        #expect(window.isOpen(at: NetTestSupport.date("2026-09-23T23:59:00Z")))
        #expect(window.isOpen(at: window.endsAt) == false)
    }

    @Test func theDaysLeftCountDownToTonight() throws {
        let window = try #require(FreeWindow(spaceCreatedAt: createdAt, days: 3, calendar: calendar))
        #expect(window.daysAfterToday(at: createdAt, calendar: calendar) == 3)
        #expect(window.daysAfterToday(at: NetTestSupport.date("2026-09-21T08:00:00Z"), calendar: calendar) == 2)
        #expect(window.daysAfterToday(at: NetTestSupport.date("2026-09-23T21:00:00Z"), calendar: calendar) == 0)
    }

    @Test func aPartnerWhoJoinsTwoDaysLaterGetsTheRestOfTheSameWindow() throws {
        let window = try #require(FreeWindow(spaceCreatedAt: createdAt, days: 3, calendar: calendar))
        let joined = createdAt.addingTimeInterval(2 * 86_400)
        #expect(window.isOpen(at: joined))
        #expect(window.daysAfterToday(at: joined, calendar: calendar) == 1)
    }

    @Test func noDaysOrNoCreationDateMeansNoWindow() {
        #expect(FreeWindow(spaceCreatedAt: createdAt, days: 0, calendar: calendar) == nil)
        #expect(FreeWindow(spaceCreatedAt: nil, days: 3, calendar: calendar) == nil)
    }

    @Test func anOpenWindowUnlocksTheWidgetsAndAClosedOneDoesNot() throws {
        let space = SpaceDTO(id: UUID(), createdAt: createdAt)
        let window = FreeWindow(spaceCreatedAt: createdAt, days: 3, calendar: calendar)
        let inside = NetTestSupport.date("2026-09-22T10:00:00Z")
        let after = NetTestSupport.date("2026-09-25T10:00:00Z")
        #expect(WidgetPremiumRule.isPremium(space: space, now: inside, monetizationEnabled: true, freeWindow: window))
        #expect(WidgetPremiumRule.isPremium(space: space, now: after, monetizationEnabled: true, freeWindow: window) == false)
    }
}

@Suite struct NetFreeWindowEntitlementTests {
    private let calendar = DomainClock.calendar()
    private let createdAt = NetTestSupport.date("2026-09-20T10:00:00Z")

    private func space(in world: TestWorld) async throws -> SpaceDTO {
        try await world.repositories.spaces.create(displayCurrency: "USD", creatorMemberId: world.me.id, now: createdAt)
    }

    private func service(
        world: TestWorld,
        at moment: Date,
        monetizationEnabled: Bool = true,
        freeDays: Int = 3,
        local: [StoreSubscription] = [],
        device: DeviceEntitlementStore? = nil
    ) -> EntitlementService {
        EntitlementService(
            client: NetTestSupport.client(transport: FakeTransport([.empty(500)]), retry: .noRetries),
            spaces: world.repositories.spaces,
            monetization: FixedMonetization(isEnabled: monetizationEnabled, freeDays: freeDays),
            store: InMemorySecretStore(),
            local: StubLocalEntitlements(local),
            appTransaction: StubAppTransaction.production,
            device: device,
            calendar: calendar,
            now: { moment }
        )
    }

    @Test func insideTheWindowEverythingIsOpenWithoutAPurchase() async throws {
        let world = try await TestWorld.make()
        let space = try await space(in: world)
        let resolution = await service(world: world, at: createdAt.addingTimeInterval(3_600))
            .refreshResolution(spaceId: space.id)
        #expect(resolution.state.isPremium)
        #expect(resolution.state.freeWindowEndsAt == NetTestSupport.date("2026-09-24T00:00:00Z"))
        #expect(resolution.readOnlyCause == nil)
    }

    @Test func afterTheWindowTheSpaceIsReadOnly() async throws {
        let world = try await TestWorld.make()
        let space = try await space(in: world)
        let resolution = await service(world: world, at: NetTestSupport.date("2026-09-24T00:00:00Z"))
            .refreshResolution(spaceId: space.id)
        #expect(resolution.state == .readOnly)
        #expect(resolution.readOnlyCause == .neverSubscribed)
    }

    @Test func thePartnerWhoJoinsOnTheSecondDaySeesTheSameEnd() async throws {
        let world = try await TestWorld.make()
        let space = try await space(in: world)
        let joined = createdAt.addingTimeInterval(2 * 86_400)
        let state = await service(world: world, at: joined).refresh(spaceId: space.id)
        let endsAt = try #require(state.freeWindowEndsAt)
        #expect(endsAt == NetTestSupport.date("2026-09-24T00:00:00Z"))
        #expect(FreeWindow(endsAt: endsAt).daysAfterToday(at: joined, calendar: calendar) == 1)
    }

    @Test func freeDaysFromTheServerChangeTheLength() async throws {
        let world = try await TestWorld.make()
        let space = try await space(in: world)
        let fifthDay = createdAt.addingTimeInterval(5 * 86_400)
        #expect(await service(world: world, at: fifthDay, freeDays: 3).refresh(spaceId: space.id) == .readOnly)
        let longer = await service(world: world, at: fifthDay, freeDays: 7).refresh(spaceId: space.id)
        #expect(longer.freeWindowEndsAt == NetTestSupport.date("2026-09-28T00:00:00Z"))
        #expect(await service(world: world, at: createdAt, freeDays: 0).refresh(spaceId: space.id) == .readOnly)
    }

    @Test func monetizationOffIsFreeWhateverTheWindowSays() async throws {
        let world = try await TestWorld.make()
        let space = try await space(in: world)
        let later = createdAt.addingTimeInterval(30 * 86_400)
        #expect(await service(world: world, at: later, monetizationEnabled: false).refresh(spaceId: space.id) == .monetizationOff)
        #expect(await service(world: world, at: createdAt, monetizationEnabled: false).refresh(spaceId: space.id) == .monetizationOff)
    }

    @Test func aRealTrialWinsOverTheWindow() async throws {
        let world = try await TestWorld.make()
        let space = try await space(in: world)
        let bought = createdAt.addingTimeInterval(86_400)
        let endsAt = bought.addingTimeInterval(14 * 86_400)
        let trial = SubscriptionTestSupport.record(for: space.id, purchasedAt: bought, expiresAt: endsAt, isInIntroOffer: true)
        let state = await service(world: world, at: bought, local: [trial]).refresh(spaceId: space.id)
        #expect(state == .trial(daysLeft: 14, endsAt: endsAt))
        #expect(state.freeWindowEndsAt == nil)
    }

    @Test func theCachedStateAtLaunchKnowsTheWindow() async throws {
        let world = try await TestWorld.make()
        let space = try await space(in: world)
        let inside = await service(world: world, at: createdAt).cachedState(space: space)
        #expect(inside.freeWindowEndsAt != nil)
        let after = await service(world: world, at: createdAt.addingTimeInterval(4 * 86_400)).cachedState(space: space)
        #expect(after == .readOnly)
    }

    @Test func theWindowIsNeverRememberedAsAPurchaseOnTheDevice() async throws {
        let world = try await TestWorld.make()
        let space = try await space(in: world)
        let suiteName = "corbie.tests.freewindow.device." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let device = DeviceEntitlementStore(defaults: defaults)
        _ = await service(world: world, at: createdAt, device: device).refresh(spaceId: space.id)
        #expect(device.snapshot(spaceId: space.id, at: createdAt) == nil)
        let after = createdAt.addingTimeInterval(4 * 86_400)
        #expect(await service(world: world, at: after, device: device).cachedState(space: space) == .readOnly)
    }

    @Test func theWindowIsNotMirroredIntoTheSharedSpace() async throws {
        let world = try await TestWorld.make()
        let space = try await space(in: world)
        _ = await service(world: world, at: createdAt).refresh(spaceId: space.id)
        let stored = try #require(try await world.repositories.spaces.space(id: space.id))
        #expect(stored.subscriptionStatus != .active)
        #expect(stored.subscriptionStatus != .trial)
    }
}

@MainActor
@Suite struct NetFreeWindowGateTests {
    @Test func theWindowNeverShowsThePaywall() {
        let analytics = RecordingAnalytics()
        let endsAt = NetTestSupport.date("2026-09-24T00:00:00Z")
        let gate = PremiumGate(state: .freeWindow(FreeWindow(endsAt: endsAt)), analytics: analytics)
        for action in PremiumAction.allCases {
            #expect(gate.require(action))
        }
        gate.presentPaywall(reason: .readOnly)
        #expect(gate.pendingPaywall == nil)
        #expect(gate.freeWindowEndsAt == endsAt)
        #expect(analytics.events.isEmpty)
    }
}
