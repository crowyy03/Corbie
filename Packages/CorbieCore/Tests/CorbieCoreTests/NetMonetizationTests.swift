import Foundation
import Testing
@testable import CorbieCore

@Suite struct NetMonetizationFlagTests {
    @Test func aFlagThatWasNeverFetchedIsOn() {
        let (store, suiteName) = MonetizationTestSupport.freshStore()
        defer { MonetizationTestSupport.remove(suiteName: suiteName) }
        #expect(store.fetchedValue == nil)
        #expect(store.isEnabled)
    }

    @Test func theServerAnswerIsStoredForTheExtensionsToRead() async {
        let (store, suiteName) = MonetizationTestSupport.freshStore()
        defer { MonetizationTestSupport.remove(suiteName: suiteName) }
        let transport = FakeTransport(json: #"{"monetizationEnabled":true}"#)
        let flag = ServerMonetizationFlag(client: NetTestSupport.client(transport: transport), store: store)

        #expect(await flag.refresh())
        #expect(MonetizationFlagStore(suiteName: suiteName).isEnabled)
        #expect(transport.lastRequest?.url.path.hasSuffix("/functions/v1/config") == true)
        #expect(transport.lastRequest?.method == .get)
        #expect(transport.lastRequest?.headers["Authorization"] == nil)
    }

    @Test func aFailedFetchBeforeAnyAnswerCountsAsPaid() async {
        let (store, suiteName) = MonetizationTestSupport.freshStore()
        defer { MonetizationTestSupport.remove(suiteName: suiteName) }
        let flag = ServerMonetizationFlag(
            client: NetTestSupport.client(transport: FakeTransport([.urlFailure(.notConnectedToInternet)]), retry: .noRetries),
            store: store
        )

        #expect(await flag.refresh())
        #expect(store.fetchedValue == nil)
    }

    @Test func aStoredFreeAnswerStillWinsOverTheDefault() {
        let (store, suiteName) = MonetizationTestSupport.freshStore()
        defer { MonetizationTestSupport.remove(suiteName: suiteName) }
        store.record(false)
        #expect(store.isEnabled == false)
    }

    @Test func aFailedFetchKeepsAPaidAnswerRatherThanFallingBackToFree() async {
        let (store, suiteName) = MonetizationTestSupport.freshStore()
        defer { MonetizationTestSupport.remove(suiteName: suiteName) }
        store.record(true)
        let flag = ServerMonetizationFlag(
            client: NetTestSupport.client(transport: FakeTransport([.empty(500)]), retry: .noRetries),
            store: store
        )

        #expect(await flag.refresh())
        #expect(store.fetchedValue == true)
    }

    @Test func theServerCanTurnMonetizationBackOff() async {
        let (store, suiteName) = MonetizationTestSupport.freshStore()
        defer { MonetizationTestSupport.remove(suiteName: suiteName) }
        store.record(true)
        let flag = ServerMonetizationFlag(
            client: NetTestSupport.client(transport: FakeTransport(json: #"{"monetizationEnabled":false}"#)),
            store: store
        )

        #expect(await flag.refresh() == false)
        #expect(store.fetchedValue == false)
    }

    @Test func onlyAChangedAnswerAsksTheWidgetsToRedraw() async {
        let (store, suiteName) = MonetizationTestSupport.freshStore()
        defer { MonetizationTestSupport.remove(suiteName: suiteName) }
        let changes = ChangeCounter()
        let transport = FakeTransport([
            .json(#"{"monetizationEnabled":false}"#),
            .json(#"{"monetizationEnabled":false}"#),
            .json(#"{"monetizationEnabled":true}"#),
        ])
        let flag = ServerMonetizationFlag(
            client: NetTestSupport.client(transport: transport),
            store: store,
            onChange: { changes.increment() }
        )

        _ = await flag.refresh()
        #expect(changes.count == 1)
        _ = await flag.refresh()
        #expect(changes.count == 1)
        _ = await flag.refresh()
        #expect(changes.count == 2)
    }

    @Test func aMalformedAnswerChangesNothing() async {
        let (store, suiteName) = MonetizationTestSupport.freshStore()
        defer { MonetizationTestSupport.remove(suiteName: suiteName) }
        store.record(true)
        let flag = ServerMonetizationFlag(
            client: NetTestSupport.client(transport: FakeTransport(json: #"{"monetizationEnabled":"yes"}"#)),
            store: store
        )

        #expect(await flag.refresh())
    }

    #if DEBUG
    @Test func theDebugOverrideWinsOverTheServerAnswer() {
        let (store, suiteName) = MonetizationTestSupport.freshStore()
        defer { MonetizationTestSupport.remove(suiteName: suiteName) }
        store.record(false)
        DebugMonetizationOverride.store(.on, suiteName: suiteName)
        #expect(store.isEnabled)
        DebugMonetizationOverride.store(.off, suiteName: suiteName)
        store.record(true)
        #expect(store.isEnabled == false)
        DebugMonetizationOverride.store(nil, suiteName: suiteName)
        #expect(store.isEnabled)
    }
    #endif
}

@Suite struct NetMonetizationEntitlementTests {
    private func service(
        world: TestWorld,
        monetizationEnabled: Bool,
        local: [StoreSubscription] = [],
        notifications: NotificationScheduler? = nil
    ) -> EntitlementService {
        EntitlementService(
            client: NetTestSupport.client(transport: FakeTransport([.empty(500)]), retry: .noRetries),
            spaces: world.repositories.spaces,
            monetization: FixedMonetization(isEnabled: monetizationEnabled),
            store: InMemorySecretStore(),
            local: StubLocalEntitlements(local),
            appTransaction: StubAppTransaction.production,
            notifications: notifications,
            now: { NetTestSupport.date("2026-09-20T10:00:00Z") }
        )
    }

    @Test func monetizationOffMakesEveryoneFullAccessWithNoTrialClock() async throws {
        let world = try await TestWorld.make()
        let state = await service(world: world, monetizationEnabled: false).refresh(spaceId: world.space.id)
        #expect(state == .monetizationOff)
        #expect(state.isPremium)
        #expect(state.isReadOnly == false)
        #expect(state.trialDaysLeft == nil)
        #expect(state.isMonetizationOff)
    }

    @Test func monetizationOffIgnoresALapsedSubscription() async throws {
        let world = try await TestWorld.make()
        let lapsed = SubscriptionTestSupport.record(
            for: world.space.id,
            purchasedAt: NetTestSupport.date("2026-07-01T10:00:00Z"),
            expiresAt: NetTestSupport.date("2026-08-01T10:00:00Z"),
            renewal: .expired
        )
        let state = await service(world: world, monetizationEnabled: false, local: [lapsed])
            .refresh(spaceId: world.space.id)
        #expect(state == .monetizationOff)
    }

    @Test func monetizationOffWritesNothingIntoTheSharedSpace() async throws {
        let world = try await TestWorld.make()
        let before = try await world.repositories.spaces.space(id: world.space.id)
        _ = await service(world: world, monetizationEnabled: false).refresh(spaceId: world.space.id)
        let after = try await world.repositories.spaces.space(id: world.space.id)
        #expect(after?.subscriptionStatus == before?.subscriptionStatus)
        #expect(after?.subscriptionExpiresAt == before?.subscriptionExpiresAt)
    }

    @Test func monetizationOffCancelsAPendingTrialNotice() async throws {
        let world = try await TestWorld.make()
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(client: center, calendar: DomainClock.calendar())
        _ = try await scheduler.scheduleTrialEnding(
            endsAt: NetTestSupport.date("2026-10-04T10:00:00Z"),
            now: NetTestSupport.date("2026-09-20T10:00:00Z")
        )
        _ = await service(world: world, monetizationEnabled: false, notifications: scheduler)
            .refresh(spaceId: world.space.id)
        #expect(await center.requests.isEmpty)
        #expect(await center.removedIdentifiers.contains(NotificationIdentifier.trialEnding))
    }

    @Test func monetizationOnKeepsTheExistingResolution() async throws {
        let world = try await TestWorld.make()
        let state = await service(world: world, monetizationEnabled: true).refresh(spaceId: world.space.id)
        #expect(state == .readOnly)

        let endsAt = NetTestSupport.date("2026-10-04T10:00:00Z")
        let trial = SubscriptionTestSupport.record(
            for: world.space.id,
            purchasedAt: NetTestSupport.date("2026-09-20T10:00:00Z"),
            expiresAt: endsAt,
            isInIntroOffer: true
        )
        let trialState = await service(world: world, monetizationEnabled: true, local: [trial])
            .refresh(spaceId: world.space.id)
        #expect(trialState == .trial(daysLeft: 14, endsAt: endsAt))
    }

    @Test func theFreePeriodLeavesNothingBehindThatUnlocksThePaidApp() async throws {
        let world = try await TestWorld.make()
        let off = service(world: world, monetizationEnabled: false)
        _ = await off.refresh(spaceId: world.space.id)
        let space = try #require(try await world.repositories.spaces.space(id: world.space.id))
        #expect(await service(world: world, monetizationEnabled: true).cachedState(space: space) == .readOnly)
    }

    @Test func theCachedStateFollowsTheFlag() async throws {
        let world = try await TestWorld.make()
        var space = world.space
        space.subscriptionStatus = .expired
        #expect(await service(world: world, monetizationEnabled: false).cachedState(space: space) == .monetizationOff)
        #expect(await service(world: world, monetizationEnabled: true).cachedState(space: space) == .readOnly)
    }

    @Test func withoutASpaceTheFlagDecidesBetweenFreeAndReadOnly() async throws {
        let world = try await TestWorld.make()
        let off = service(world: world, monetizationEnabled: false)
        #expect(off.stateWithoutSpace() == .monetizationOff)
        #expect(await off.refreshWithoutSpace() == .monetizationOff)
        let on = service(world: world, monetizationEnabled: true)
        #expect(on.stateWithoutSpace() == .readOnly)
        #expect(await on.refreshWithoutSpace() == .readOnly)
    }
}

@MainActor
@Suite struct NetMonetizationGateTests {
    @Test func monetizationOffNeverAsksForMoney() {
        let analytics = RecordingAnalytics()
        let gate = PremiumGate(state: .monetizationOff, analytics: analytics)
        for action in PremiumAction.allCases {
            #expect(gate.require(action))
        }
        gate.presentPaywall(reason: .settings)
        #expect(gate.pendingPaywall == nil)
        #expect(gate.isMonetizationOff)
        #expect(analytics.events.isEmpty)
    }

    @Test func monetizationOnStillShowsThePaywallOnRequest() {
        let gate = PremiumGate(state: .readOnly, analytics: RecordingAnalytics())
        gate.presentPaywall(reason: .settings)
        #expect(gate.pendingPaywall?.reason == .settings)
        #expect(gate.isMonetizationOff == false)
    }
}

private final class ChangeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func increment() {
        lock.lock()
        value += 1
        lock.unlock()
    }
}
