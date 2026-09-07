import Foundation
import Testing
@testable import CorbieCore

@Suite struct NetEntitlementResolverTests {
    private let now = NetTestSupport.date("2026-09-05T10:00:00Z")

    private func inputs(
        local: LocalEntitlement? = nil,
        server: ServerEntitlement? = nil,
        space: MirroredEntitlement? = nil
    ) -> EntitlementInputs {
        EntitlementInputs(local: local, server: server, space: space, now: now)
    }

    private func introOffer(endsIn days: Double) -> LocalEntitlement {
        LocalEntitlement(
            productId: "app.corbie.yearly",
            expiresAt: now.addingTimeInterval(days * 86_400),
            isInIntroOffer: true
        )
    }

    @Test func aFreshSpaceWithoutASubscriptionIsReadOnly() {
        let state = EntitlementResolver.resolve(inputs())
        #expect(state == .readOnly)
        #expect(state.isPremium == false)
        #expect(state.isReadOnly)
        #expect(state.trialDaysLeft == nil)
    }

    @Test func theTrialComesFromTheStoreKitExpirationDate() {
        let state = EntitlementResolver.resolve(inputs(local: introOffer(endsIn: 14)))
        #expect(state == .trial(daysLeft: 14, endsAt: now.addingTimeInterval(14 * 86_400)))
        #expect(state.isPremium)
        #expect(state.trialEndsAt == now.addingTimeInterval(14 * 86_400))
        #expect(state.isTrialEndingSoon == false)
        #expect(EntitlementResolver.resolve(inputs(local: introOffer(endsIn: 2))).isTrialEndingSoon)
    }

    @Test func aPaidPeriodIsPremiumRatherThanATrial() {
        let expiry = now.addingTimeInterval(360 * 86_400)
        let state = EntitlementResolver.resolve(
            inputs(local: LocalEntitlement(productId: "app.corbie.yearly", expiresAt: expiry))
        )
        #expect(state == .premium(source: .storeKit, expiresAt: expiry))
        #expect(state.trialDaysLeft == nil)
    }

    @Test func anExpiredIntroPeriodWithoutAnEntitlementIsReadOnly() {
        let state = EntitlementResolver.resolve(inputs(local: introOffer(endsIn: -1)))
        #expect(state == .readOnly)
    }

    @Test func theLocalEntitlementIsAskedBeforeTheServer() {
        let localExpiry = now.addingTimeInterval(30 * 86_400)
        let state = EntitlementResolver.resolve(
            inputs(
                local: LocalEntitlement(productId: "app.corbie.monthly", expiresAt: localExpiry),
                server: ServerEntitlement(status: .active, expiresAt: now.addingTimeInterval(360 * 86_400))
            )
        )
        #expect(state == .premium(source: .storeKit, expiresAt: localExpiry))
    }

    @Test func thePartnerDeviceHasNoTransactionsAndStillGetsAccess() {
        let expiry = now.addingTimeInterval(86_400)
        let state = EntitlementResolver.resolve(inputs(server: ServerEntitlement(status: .active, expiresAt: expiry)))
        #expect(state == .premium(source: .server, expiresAt: expiry))
    }

    @Test func theMirroredSpaceIsTheLastFallback() {
        let expiry = now.addingTimeInterval(200 * 86_400)
        let state = EntitlementResolver.resolve(
            inputs(
                server: ServerEntitlement(status: .none),
                space: MirroredEntitlement(status: .active, expiresAt: expiry)
            )
        )
        #expect(state == .premium(source: .space, expiresAt: expiry))

        let trial = EntitlementResolver.resolve(
            inputs(space: MirroredEntitlement(status: .trial, expiresAt: now.addingTimeInterval(3 * 86_400)))
        )
        #expect(trial == .trial(daysLeft: 3, endsAt: now.addingTimeInterval(3 * 86_400)))

        let lapsed = EntitlementResolver.resolve(
            inputs(space: MirroredEntitlement(status: .active, expiresAt: now.addingTimeInterval(-1)))
        )
        #expect(lapsed == .readOnly)

        let withoutAnEnd = EntitlementResolver.resolve(inputs(space: MirroredEntitlement(status: .trial, expiresAt: nil)))
        #expect(withoutAnEnd == .readOnly)
    }

    @Test func aServerEntitlementPastItsExpiryIsNotActive() {
        let state = EntitlementResolver.resolve(
            inputs(server: ServerEntitlement(status: .active, expiresAt: now.addingTimeInterval(-1)))
        )
        #expect(state == .readOnly)
    }

    @Test func theGracePeriodKeepsAccessOnBothDevices() {
        let graceEnd = now.addingTimeInterval(3 * 86_400)
        let fromServer = EntitlementResolver.resolve(
            inputs(server: ServerEntitlement(status: .inGracePeriod, expiresAt: graceEnd))
        )
        #expect(fromServer == .grace(expiresAt: graceEnd))
        #expect(fromServer.isPremium)

        let fromStoreKit = EntitlementResolver.resolve(
            inputs(
                local: LocalEntitlement(
                    productId: "app.corbie.yearly",
                    renewal: .inGracePeriod,
                    expiresAt: now.addingTimeInterval(-86_400),
                    gracePeriodExpiresAt: graceEnd
                )
            )
        )
        #expect(fromStoreKit == .grace(expiresAt: graceEnd))
    }

    @Test func billingRetryIsPremiumOnlyWhileTheGracePeriodRuns() {
        let running = EntitlementResolver.resolve(
            inputs(server: ServerEntitlement(status: .inBillingRetry, expiresAt: now.addingTimeInterval(86_400)))
        )
        #expect(running == .grace(expiresAt: now.addingTimeInterval(86_400)))

        let over = EntitlementResolver.resolve(
            inputs(server: ServerEntitlement(status: .inBillingRetry, expiresAt: now.addingTimeInterval(-1)))
        )
        #expect(over == .readOnly)

        let localOver = EntitlementResolver.resolve(
            inputs(
                local: LocalEntitlement(
                    productId: "app.corbie.yearly",
                    renewal: .inBillingRetry,
                    expiresAt: now.addingTimeInterval(-86_400),
                    gracePeriodExpiresAt: now.addingTimeInterval(-1)
                )
            )
        )
        #expect(localOver == .readOnly)
    }

    @Test func aRefundBeatsAnyOtherSource() {
        let state = EntitlementResolver.resolve(
            inputs(
                local: LocalEntitlement(productId: "app.corbie.yearly", expiresAt: now.addingTimeInterval(86_400)),
                server: ServerEntitlement(status: .revoked),
                space: MirroredEntitlement(status: .active, expiresAt: now.addingTimeInterval(86_400))
            )
        )
        #expect(state == .readOnly)

        let revokedLocally = EntitlementResolver.resolve(
            inputs(
                local: LocalEntitlement(productId: "app.corbie.yearly", renewal: .revoked),
                space: MirroredEntitlement(status: .active, expiresAt: nil)
            )
        )
        #expect(revokedLocally == .readOnly)
    }

    @Test func theTrialBoundaryIsExclusive() {
        #expect(EntitlementResolver.trialDaysLeft(endsAt: now, now: now) == nil)
        #expect(EntitlementResolver.trialDaysLeft(endsAt: now.addingTimeInterval(-1), now: now) == nil)
        #expect(EntitlementResolver.trialDaysLeft(endsAt: now.addingTimeInterval(1), now: now) == 1)
        #expect(EntitlementResolver.trialDaysLeft(endsAt: now.addingTimeInterval(86_400), now: now) == 1)
        #expect(EntitlementResolver.trialDaysLeft(endsAt: now.addingTimeInterval(86_401), now: now) == 2)
        #expect(EntitlementResolver.trialDaysLeft(endsAt: now.addingTimeInterval(14 * 86_400), now: now) == 14)
        #expect(EntitlementResolver.trialDaysLeft(endsAt: nil, now: now) == nil)
    }

    @Test func theMirroredStatusTellsAnExpiredSubscriptionFromAnUnknownOne() {
        let endsAt = now.addingTimeInterval(86_400)
        #expect(EntitlementService.mirroredStatus(.trial(daysLeft: 3, endsAt: endsAt), server: nil) == .trial)
        #expect(EntitlementService.mirroredStatus(.premium(source: .server, expiresAt: nil), server: nil) == .active)
        #expect(EntitlementService.mirroredStatus(.grace(expiresAt: nil), server: nil) == .active)
        #expect(EntitlementService.mirroredStatus(.readOnly, server: nil) == .readonly)
        #expect(EntitlementService.mirroredStatus(.readOnly, server: ServerEntitlement(status: .none)) == .readonly)
        #expect(EntitlementService.mirroredStatus(.readOnly, server: ServerEntitlement(status: .expired)) == .expired)
        #expect(EntitlementService.mirroredStatus(.readOnly, server: ServerEntitlement(status: .revoked)) == .expired)
    }
}

@Suite struct NetEntitlementServiceTests {
    private func payload(_ spaceId: UUID, status: String, expiresAt: String?) -> String {
        let expiry = expiresAt.map { "\"\($0)\"" } ?? "null"
        return """
        {"spaceId":"\(spaceId.uuidString.lowercased())","status":"\(status)","productId":"app.corbie.yearly",\
        "expiresAt":\(expiry),"updatedAt":"2026-09-05T10:00:00Z"}
        """
    }

    @Test func refreshCachesTheServerAnswerAndMirrorsItOntoTheSpace() async throws {
        let world = try await TestWorld.make()
        let transport = FakeTransport(json: payload(world.space.id, status: "active", expiresAt: "2027-09-05T10:00:00Z"))
        let secrets = InMemorySecretStore()
        let service = EntitlementService(
            client: NetTestSupport.client(transport: transport),
            spaces: world.repositories.spaces,
            store: secrets,
            local: StubLocalEntitlements(nil),
            now: { NetTestSupport.date("2026-09-20T10:00:00Z") }
        )

        let state = await service.refresh(spaceId: world.space.id)
        #expect(state == .premium(source: .server, expiresAt: NetTestSupport.date("2027-09-05T10:00:00Z")))
        #expect(await service.state == state)

        let cached = await service.cachedEntitlement(spaceId: world.space.id)
        #expect(cached?.status == .active)
        #expect(cached?.productId == "app.corbie.yearly")

        let stored = try await world.repositories.spaces.space(id: world.space.id)
        #expect(stored?.subscriptionStatus == .active)
        #expect(stored?.subscriptionExpiresAt == NetTestSupport.date("2027-09-05T10:00:00Z"))
    }

    @Test func aRunningIntroOfferIsMirroredAsATrialWithItsEndDate() async throws {
        let world = try await TestWorld.make()
        let now = NetTestSupport.date("2026-09-20T10:00:00Z")
        let endsAt = NetTestSupport.date("2026-10-04T10:00:00Z")
        let service = EntitlementService(
            client: NetTestSupport.client(
                transport: FakeTransport(json: payload(world.space.id, status: "none", expiresAt: nil))
            ),
            spaces: world.repositories.spaces,
            store: InMemorySecretStore(),
            local: StubLocalEntitlements(
                LocalEntitlement(productId: "app.corbie.yearly", expiresAt: endsAt, isInIntroOffer: true)
            ),
            now: { now }
        )

        let state = await service.refresh(spaceId: world.space.id)
        #expect(state == .trial(daysLeft: 14, endsAt: endsAt))

        let stored = try await world.repositories.spaces.space(id: world.space.id)
        #expect(stored?.subscriptionStatus == .trial)
        #expect(stored?.subscriptionExpiresAt == endsAt)
    }

    @Test func theTrialNoticeIsScheduledTwoDaysBeforeTheStoreKitExpiry() async throws {
        let world = try await TestWorld.make()
        let now = NetTestSupport.date("2026-09-20T10:00:00Z")
        let endsAt = NetTestSupport.date("2026-10-04T10:00:00Z")
        let center = FakeNotificationCenter()
        let service = EntitlementService(
            client: NetTestSupport.client(
                transport: FakeTransport(json: payload(world.space.id, status: "none", expiresAt: nil))
            ),
            spaces: world.repositories.spaces,
            store: InMemorySecretStore(),
            local: StubLocalEntitlements(
                LocalEntitlement(productId: "app.corbie.yearly", expiresAt: endsAt, isInIntroOffer: true)
            ),
            notifications: NotificationScheduler(client: center, calendar: DomainClock.calendar()),
            now: { now }
        )

        _ = await service.refresh(spaceId: world.space.id)
        let scheduled = await center.requests
        #expect(scheduled.map(\.id) == [NotificationIdentifier.trialEnding])
        #expect(scheduled.first?.fireDate == NetTestSupport.date("2026-10-02T10:00:00Z"))
        #expect(scheduled.first?.content.titleKey == NotificationStrings.trialEndingTitle)
        #expect(NotificationKind.trialEnding.isEnabled(in: NotificationPrefs(weeklyRecap: false)))
    }

    @Test func theTrialNoticeIsDroppedOnceTheSubscriptionIsPaid() async throws {
        let world = try await TestWorld.make()
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(client: center, calendar: DomainClock.calendar())
        _ = try await scheduler.scheduleTrialEnding(
            endsAt: NetTestSupport.date("2026-10-04T10:00:00Z"),
            now: NetTestSupport.date("2026-09-20T10:00:00Z")
        )
        #expect(await center.requests.isEmpty == false)

        let service = EntitlementService(
            client: NetTestSupport.client(
                transport: FakeTransport(json: payload(world.space.id, status: "active", expiresAt: "2027-09-05T10:00:00Z"))
            ),
            spaces: world.repositories.spaces,
            store: InMemorySecretStore(),
            local: StubLocalEntitlements(nil),
            notifications: scheduler,
            now: { NetTestSupport.date("2026-09-20T10:00:00Z") }
        )

        _ = await service.refresh(spaceId: world.space.id)
        #expect(await center.requests.isEmpty)
        #expect(await center.removedIdentifiers.contains(NotificationIdentifier.trialEnding))
    }

    @Test func anOfflineRefreshFallsBackToTheKeychainCopy() async throws {
        let world = try await TestWorld.make()
        let secrets = InMemorySecretStore()
        let online = EntitlementService(
            client: NetTestSupport.client(
                transport: FakeTransport(json: payload(world.space.id, status: "active", expiresAt: "2027-09-05T10:00:00Z"))
            ),
            spaces: world.repositories.spaces,
            store: secrets,
            now: { NetTestSupport.date("2026-09-20T10:00:00Z") }
        )
        _ = await online.refresh(spaceId: world.space.id)

        let offline = EntitlementService(
            client: NetTestSupport.client(
                transport: FakeTransport([.urlFailure(.notConnectedToInternet)]),
                retry: .noRetries
            ),
            spaces: world.repositories.spaces,
            store: secrets,
            now: { NetTestSupport.date("2026-09-21T10:00:00Z") }
        )
        let state = await offline.refresh(spaceId: world.space.id)
        #expect(state == .premium(source: .server, expiresAt: NetTestSupport.date("2027-09-05T10:00:00Z")))
    }

    @Test func anUnknownSpaceLeavesTheGateClosed() async throws {
        let world = try await TestWorld.make()
        let service = EntitlementService(
            client: NetTestSupport.client(transport: FakeTransport(json: payload(world.space.id, status: "none", expiresAt: nil))),
            spaces: world.repositories.spaces,
            store: InMemorySecretStore(),
            now: { NetTestSupport.date("2026-09-05T10:00:00Z") }
        )
        let state = await service.refresh(spaceId: world.space.id)
        #expect(state == .readOnly)
        let stored = try await world.repositories.spaces.space(id: world.space.id)
        #expect(stored?.subscriptionStatus == .readonly)
    }

    @Test func theCachedStateReadsTheKeychainAndTheMirroredSpace() async throws {
        let world = try await TestWorld.make()
        let secrets = InMemorySecretStore()
        let online = EntitlementService(
            client: NetTestSupport.client(
                transport: FakeTransport(json: payload(world.space.id, status: "active", expiresAt: "2027-09-05T10:00:00Z"))
            ),
            spaces: world.repositories.spaces,
            store: secrets,
            now: { NetTestSupport.date("2026-09-20T10:00:00Z") }
        )
        _ = await online.refresh(spaceId: world.space.id)

        let offline = EntitlementService(
            client: NetTestSupport.client(transport: FakeTransport([.urlFailure(.notConnectedToInternet)]), retry: .noRetries),
            spaces: world.repositories.spaces,
            store: secrets,
            now: { NetTestSupport.date("2026-09-21T10:00:00Z") }
        )
        let stored = try #require(try await world.repositories.spaces.space(id: world.space.id))
        #expect(await offline.cachedState(space: stored).isPremium)

        let mirroredOnly = EntitlementService(
            client: NetTestSupport.client(transport: FakeTransport([.urlFailure(.notConnectedToInternet)]), retry: .noRetries),
            spaces: world.repositories.spaces,
            store: InMemorySecretStore(),
            now: { NetTestSupport.date("2026-09-21T10:00:00Z") }
        )
        #expect(await mirroredOnly.cachedState(space: stored) == .premium(
            source: .space,
            expiresAt: NetTestSupport.date("2027-09-05T10:00:00Z")
        ))
    }

    @Test func clearingTheCacheForgetsTheServerAnswer() async throws {
        let world = try await TestWorld.make()
        let secrets = InMemorySecretStore()
        let service = EntitlementService(
            client: NetTestSupport.client(transport: FakeTransport(json: payload(world.space.id, status: "active", expiresAt: nil))),
            spaces: world.repositories.spaces,
            store: secrets
        )
        _ = await service.refresh(spaceId: world.space.id)
        #expect(await service.cachedEntitlement(spaceId: world.space.id) != nil)
        await service.clearCache(spaceId: world.space.id)
        #expect(await service.cachedEntitlement(spaceId: world.space.id) == nil)
        #expect(EntitlementService.cacheKey(spaceId: world.space.id).hasPrefix("corbie.entitlement."))
    }
}
