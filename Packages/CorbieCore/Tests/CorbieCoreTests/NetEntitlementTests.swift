import Foundation
import Testing
@testable import CorbieCore

@Suite struct NetEntitlementResolverTests {
    private let now = NetTestSupport.date("2026-09-05T10:00:00Z")

    private func inputs(
        environment: StoreEnvironment = .production,
        local: LocalEntitlement? = nil,
        server: ServerEntitlement? = nil,
        space: MirroredEntitlement? = nil
    ) -> EntitlementInputs {
        EntitlementInputs(environment: environment, local: local, server: server, space: space, now: now)
    }

    private func server(_ status: EntitlementStatus, expiresAt: Date? = nil) -> ServerEntitlement {
        ServerEntitlement(status: status, expiresAt: expiresAt, environment: .production)
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
                server: server(.active, expiresAt: now.addingTimeInterval(360 * 86_400))
            )
        )
        #expect(state == .premium(source: .storeKit, expiresAt: localExpiry))
    }

    @Test func thePartnerDeviceHasNoTransactionsAndStillGetsAccess() {
        let expiry = now.addingTimeInterval(86_400)
        let state = EntitlementResolver.resolve(inputs(server: server(.active, expiresAt: expiry)))
        #expect(state == .premium(source: .server, expiresAt: expiry))
    }

    @Test func theMirroredSpaceIsTheLastFallback() {
        let expiry = now.addingTimeInterval(200 * 86_400)
        let state = EntitlementResolver.resolve(
            inputs(
                server: server(.none),
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
        let state = EntitlementResolver.resolve(inputs(server: server(.active, expiresAt: now.addingTimeInterval(-1))))
        #expect(state == .readOnly)
    }

    @Test func theGracePeriodKeepsAccessOnBothDevices() {
        let graceEnd = now.addingTimeInterval(3 * 86_400)
        let fromServer = EntitlementResolver.resolve(inputs(server: server(.inGracePeriod, expiresAt: graceEnd)))
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

    @Test func aGracePeriodEndsOnItsEndDateWhateverTheSource() {
        let over = now.addingTimeInterval(-1)
        #expect(EntitlementResolver.resolve(inputs(server: server(.inGracePeriod, expiresAt: over))) == .readOnly)
        #expect(EntitlementResolver.resolve(inputs(server: server(.inGracePeriod, expiresAt: nil))) == .readOnly)
        let localOver = LocalEntitlement(
            productId: "app.corbie.yearly",
            renewal: .inGracePeriod,
            expiresAt: now.addingTimeInterval(-86_400),
            gracePeriodExpiresAt: over
        )
        #expect(EntitlementResolver.resolve(inputs(local: localOver)) == .readOnly)
        let localWithoutDates = LocalEntitlement(productId: "app.corbie.yearly", renewal: .inGracePeriod)
        #expect(EntitlementResolver.resolve(inputs(local: localWithoutDates)) == .readOnly)
    }

    @Test func billingRetryIsPremiumOnlyWhileTheGracePeriodRuns() {
        let running = EntitlementResolver.resolve(
            inputs(server: server(.inBillingRetry, expiresAt: now.addingTimeInterval(86_400)))
        )
        #expect(running == .grace(expiresAt: now.addingTimeInterval(86_400)))

        let over = EntitlementResolver.resolve(inputs(server: server(.inBillingRetry, expiresAt: now.addingTimeInterval(-1))))
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

    @Test func aRefundOfThisSpacesLatestTransactionBeatsEverySource() {
        let state = EntitlementResolver.resolve(
            inputs(
                local: LocalEntitlement(productId: "app.corbie.yearly", renewal: .revoked),
                server: server(.active, expiresAt: now.addingTimeInterval(86_400)),
                space: MirroredEntitlement(status: .active, expiresAt: nil)
            )
        )
        #expect(state == .readOnly)
    }

    @Test func aServerRevocationBeatsTheMirrorButNotThePayersOwnSubscription() {
        let payerExpiry = now.addingTimeInterval(86_400)
        let payer = EntitlementResolver.resolve(
            inputs(
                local: LocalEntitlement(productId: "app.corbie.yearly", expiresAt: payerExpiry),
                server: server(.revoked)
            )
        )
        #expect(payer == .premium(source: .storeKit, expiresAt: payerExpiry))

        let partner = EntitlementResolver.resolve(
            inputs(
                server: server(.revoked),
                space: MirroredEntitlement(status: .active, expiresAt: now.addingTimeInterval(86_400))
            )
        )
        #expect(partner == .readOnly)
    }

    @Test func aProductionBuildNeverReadsASandboxServerAnswer() {
        let sandboxActive = ServerEntitlement(
            status: .active,
            expiresAt: now.addingTimeInterval(86_400),
            environment: .sandbox
        )
        #expect(EntitlementResolver.resolve(inputs(server: sandboxActive)) == .readOnly)
        let unmarked = ServerEntitlement(status: .active, expiresAt: now.addingTimeInterval(86_400))
        #expect(EntitlementResolver.resolve(inputs(server: unmarked)) == .readOnly)
        let sandboxRevoked = ServerEntitlement(status: .revoked, environment: .sandbox)
        let productionExpiry = now.addingTimeInterval(86_400)
        #expect(
            EntitlementResolver.resolve(
                inputs(server: sandboxRevoked, space: MirroredEntitlement(status: .active, expiresAt: productionExpiry))
            ) == .premium(source: .space, expiresAt: productionExpiry)
        )
    }

    @Test func onlyAProductionBuildReadsTheMirror() {
        let expiry = now.addingTimeInterval(86_400)
        let mirror = MirroredEntitlement(status: .active, expiresAt: expiry)
        #expect(EntitlementResolver.resolve(inputs(environment: .production, space: mirror)) == .premium(
            source: .space,
            expiresAt: expiry
        ))
        #expect(EntitlementResolver.resolve(inputs(environment: .sandbox, space: mirror)) == .readOnly)
        #expect(EntitlementResolver.resolve(inputs(environment: .xcode, space: mirror)) == .readOnly)
        let sandboxAnswer = ServerEntitlement(status: .active, expiresAt: expiry, environment: .sandbox)
        #expect(EntitlementResolver.resolve(inputs(environment: .sandbox, server: sandboxAnswer)) == .premium(
            source: .server,
            expiresAt: expiry
        ))
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

    @Test func theReadOnlyCauseSaysWhatHappened() {
        #expect(EntitlementResolver.resolution(inputs()).readOnlyCause == .neverSubscribed)
        #expect(EntitlementResolver.resolution(inputs(server: server(.none))).readOnlyCause == .neverSubscribed)

        let lapsedTrial = introOffer(endsIn: -1)
        #expect(EntitlementResolver.resolution(inputs(local: lapsedTrial)).readOnlyCause == .trialEnded)

        let lapsedPaid = LocalEntitlement(
            productId: "app.corbie.yearly",
            renewal: .expired,
            expiresAt: now.addingTimeInterval(-86_400)
        )
        #expect(EntitlementResolver.resolution(inputs(local: lapsedPaid)).readOnlyCause == .subscriptionEnded)

        let refunded = LocalEntitlement(productId: "app.corbie.yearly", renewal: .revoked)
        #expect(EntitlementResolver.resolution(inputs(local: refunded)).readOnlyCause == .subscriptionEnded)

        let partnerAfterTrial = inputs(
            server: server(.expired, expiresAt: now.addingTimeInterval(-86_400)),
            space: MirroredEntitlement(status: .trial, expiresAt: now.addingTimeInterval(-86_400))
        )
        #expect(EntitlementResolver.resolution(partnerAfterTrial).readOnlyCause == .trialEnded)

        let partnerAfterPaid = inputs(server: server(.expired, expiresAt: now.addingTimeInterval(-86_400)))
        #expect(EntitlementResolver.resolution(partnerAfterPaid).readOnlyCause == .subscriptionEnded)

        let offlinePartner = inputs(space: MirroredEntitlement(status: .expired, expiresAt: now.addingTimeInterval(-1)))
        #expect(EntitlementResolver.resolution(offlinePartner).readOnlyCause == .subscriptionEnded)

        #expect(EntitlementResolver.resolution(inputs(local: introOffer(endsIn: 3))).readOnlyCause == nil)
    }

    @Test func aSandboxSubscriptionLeavesNoCauseInAProductionBuild() {
        let sandboxExpired = ServerEntitlement(status: .expired, environment: .sandbox)
        #expect(EntitlementResolver.resolution(inputs(server: sandboxExpired)).readOnlyCause == .neverSubscribed)
    }

    @Test func theMirroredStatusKeepsWhatEnded() {
        let endsAt = now.addingTimeInterval(86_400)
        #expect(EntitlementService.mirroredStatus(EntitlementResolution(state: .trial(daysLeft: 3, endsAt: endsAt))) == .trial)
        #expect(EntitlementService.mirroredStatus(EntitlementResolution(state: .premium(source: .server, expiresAt: nil))) == .active)
        #expect(EntitlementService.mirroredStatus(EntitlementResolution(state: .grace(expiresAt: nil))) == .active)
        #expect(EntitlementService.mirroredStatus(EntitlementResolution(state: .readOnly)) == .readonly)
        #expect(
            EntitlementService.mirroredStatus(EntitlementResolution(state: .readOnly, readOnlyCause: .subscriptionEnded))
                == .expired
        )
        #expect(
            EntitlementService.mirroredStatus(EntitlementResolution(state: .readOnly, readOnlyCause: .trialEnded)) == .trial
        )
        #expect(EntitlementResolution(state: .premium(source: .server, expiresAt: nil), readOnlyCause: .trialEnded).readOnlyCause == nil)
    }
}

@Suite struct NetLocalSubscriptionTests {
    private let now = NetTestSupport.date("2026-09-20T10:00:00Z")
    private let space = UUID()

    private func record(
        for spaceId: UUID?,
        environment: StoreEnvironment = .production,
        purchasedDaysAgo: Double,
        expiresInDays: Double?,
        renewal: StoreRenewalState = .subscribed,
        isInIntroOffer: Bool = false,
        transactionId: UInt64 = 1
    ) -> StoreSubscription {
        SubscriptionTestSupport.record(
            for: spaceId,
            environment: environment,
            purchasedAt: now.addingTimeInterval(-purchasedDaysAgo * 86_400),
            expiresAt: expiresInDays.map { now.addingTimeInterval($0 * 86_400) },
            renewal: renewal,
            isInIntroOffer: isInIntroOffer,
            transactionId: transactionId
        )
    }

    @Test func onlyATransactionForThisSpaceCounts() {
        let elsewhere = record(for: UUID(), purchasedDaysAgo: 1, expiresInDays: 29)
        let noToken = record(for: nil, purchasedDaysAgo: 1, expiresInDays: 29)
        let local = LocalSubscriptions([elsewhere, noToken], environment: .production)
        #expect(local.entitlement(for: space) == nil)

        let here = record(for: space, purchasedDaysAgo: 1, expiresInDays: 29)
        #expect(LocalSubscriptions([elsewhere, here], environment: .production).entitlement(for: space) == here.entitlement)
    }

    @Test func aTransactionFromAnotherEnvironmentNeverCounts() {
        let sandbox = record(for: space, environment: .sandbox, purchasedDaysAgo: 1, expiresInDays: 29)
        let xcode = record(for: space, environment: .xcode, purchasedDaysAgo: 1, expiresInDays: 29)
        let production = LocalSubscriptions([sandbox, xcode], environment: .production)
        #expect(production.entitlement(for: space) == nil)
        #expect(production.active(at: now).isEmpty)
        #expect(LocalSubscriptions([sandbox], environment: .sandbox).entitlement(for: space) == sandbox.entitlement)
    }

    @Test func aRevocationCountsOnlyForThisSpacesLatestTransaction() {
        let refundedEarlier = record(for: space, purchasedDaysAgo: 60, expiresInDays: -30, renewal: .revoked, transactionId: 1)
        let current = record(for: space, purchasedDaysAgo: 2, expiresInDays: 28, transactionId: 2)
        let refundedElsewhere = record(for: UUID(), purchasedDaysAgo: 1, expiresInDays: 29, renewal: .revoked, transactionId: 3)
        let local = LocalSubscriptions([refundedEarlier, current, refundedElsewhere], environment: .production)
        #expect(local.entitlement(for: space)?.renewal == .subscribed)
        #expect(EntitlementResolver.resolve(EntitlementInputs(local: local.entitlement(for: space), now: now)).isPremium)

        let refundedLatest = record(for: space, purchasedDaysAgo: 1, expiresInDays: 29, renewal: .revoked, transactionId: 4)
        let refunded = LocalSubscriptions([current, refundedLatest], environment: .production)
        #expect(refunded.entitlement(for: space)?.renewal == .revoked)
    }

    @Test func anActiveSubscriptionBoughtForAnotherSpaceIsTheOneToMove() {
        let solo = UUID()
        let bought = record(for: solo, purchasedDaysAgo: 3, expiresInDays: 11, isInIntroOffer: true)
        let local = LocalSubscriptions([bought], environment: .production)
        #expect(local.activeOutside(space, at: now) == bought)
        #expect(local.activeOutside(solo, at: now) == nil)

        let lapsed = record(for: solo, purchasedDaysAgo: 40, expiresInDays: -10)
        #expect(LocalSubscriptions([lapsed], environment: .production).activeOutside(space, at: now) == nil)

        let ownActive = record(for: space, purchasedDaysAgo: 1, expiresInDays: 29, transactionId: 2)
        #expect(LocalSubscriptions([bought, ownActive], environment: .production).activeOutside(space, at: now) == nil)
    }

    @Test func restoreReconcilesThisSpacesSubscriptionOrMovesAnActiveOne() {
        let ownLapsed = record(for: space, purchasedDaysAgo: 40, expiresInDays: -10, renewal: .expired, transactionId: 1)
        #expect(LocalSubscriptions([ownLapsed], environment: .production).toReconcile(for: space, at: now) == ownLapsed)

        let activeElsewhere = record(for: UUID(), purchasedDaysAgo: 2, expiresInDays: 28, transactionId: 2)
        let both = LocalSubscriptions([ownLapsed, activeElsewhere], environment: .production)
        #expect(both.toReconcile(for: space, at: now) == activeElsewhere)
        #expect(LocalSubscriptions([], environment: .production).toReconcile(for: space, at: now) == nil)
    }
}

@Suite struct NetEntitlementServiceTests {
    private let now = NetTestSupport.date("2026-09-20T10:00:00Z")

    private func service(
        _ world: TestWorld,
        transport: FakeTransport,
        secrets: InMemorySecretStore = InMemorySecretStore(),
        local: [StoreSubscription] = [],
        appTransaction: StubAppTransaction = .production,
        notifications: NotificationScheduler? = nil,
        at moment: Date? = nil,
        retry: RetryPolicy = .default
    ) -> EntitlementService {
        let clock = moment ?? now
        return EntitlementService(
            client: NetTestSupport.client(transport: transport, retry: retry),
            spaces: world.repositories.spaces,
            monetization: FixedMonetization(isEnabled: true),
            store: secrets,
            local: StubLocalEntitlements(local),
            appTransaction: appTransaction,
            notifications: notifications,
            now: { clock }
        )
    }

    private func payload(_ spaceId: UUID, status: String, expiresAt: String?, environment: String? = "Production") -> String {
        SubscriptionTestSupport.payload(spaceId, status: status, expiresAt: expiresAt, environment: environment)
    }

    private func unreachable() -> FakeTransport {
        FakeTransport([.urlFailure(.notConnectedToInternet)])
    }

    @Test func refreshCachesTheServerAnswerAndMirrorsItOntoTheSpace() async throws {
        let world = try await TestWorld.make()
        let transport = FakeTransport(json: payload(world.space.id, status: "active", expiresAt: "2027-09-05T10:00:00Z"))
        let secrets = InMemorySecretStore()
        let service = service(world, transport: transport, secrets: secrets)

        let state = await service.refresh(spaceId: world.space.id)
        #expect(state == .premium(source: .server, expiresAt: NetTestSupport.date("2027-09-05T10:00:00Z")))
        #expect(await service.state == state)

        let cached = await service.cachedEntitlement(spaceId: world.space.id)
        #expect(cached?.status == .active)
        #expect(cached?.productId == "app.corbie.yearly")
        #expect(cached?.environment == .production)

        let stored = try await world.repositories.spaces.space(id: world.space.id)
        #expect(stored?.subscriptionStatus == .active)
        #expect(stored?.subscriptionExpiresAt == NetTestSupport.date("2027-09-05T10:00:00Z"))
    }

    @Test func theEntitlementCallCarriesTheAppTransaction() async throws {
        let world = try await TestWorld.make()
        let transport = FakeTransport(json: payload(world.space.id, status: "none", expiresAt: nil))
        _ = await service(world, transport: transport).refresh(spaceId: world.space.id)
        #expect(transport.lastRequest?.headers["X-App-Transaction"] == StubAppTransaction.production.signed)

        let unknown = FakeTransport(json: payload(world.space.id, status: "none", expiresAt: nil))
        _ = await service(world, transport: unknown, appTransaction: .unknown).refresh(spaceId: world.space.id)
        #expect(unknown.lastRequest?.headers["X-App-Transaction"] == nil)
    }

    @Test func aRunningIntroOfferIsMirroredAsATrialWithItsEndDate() async throws {
        let world = try await TestWorld.make()
        let endsAt = NetTestSupport.date("2026-10-04T10:00:00Z")
        let trial = SubscriptionTestSupport.record(
            for: world.space.id,
            purchasedAt: now,
            expiresAt: endsAt,
            isInIntroOffer: true
        )
        let service = service(
            world,
            transport: FakeTransport(json: payload(world.space.id, status: "none", expiresAt: nil)),
            local: [trial]
        )

        let state = await service.refresh(spaceId: world.space.id)
        #expect(state == .trial(daysLeft: 14, endsAt: endsAt))

        let stored = try await world.repositories.spaces.space(id: world.space.id)
        #expect(stored?.subscriptionStatus == .trial)
        #expect(stored?.subscriptionExpiresAt == endsAt)
    }

    @Test func aTrialThatEndedStaysATrialInTheMirrorSoThePartnerCanSayWhatHappened() async throws {
        let world = try await TestWorld.make()
        let endedAt = NetTestSupport.date("2026-09-18T10:00:00Z")
        let lapsedTrial = SubscriptionTestSupport.record(
            for: world.space.id,
            purchasedAt: NetTestSupport.date("2026-09-04T10:00:00Z"),
            expiresAt: endedAt,
            renewal: .expired,
            isInIntroOffer: true
        )
        let payer = service(
            world,
            transport: FakeTransport(json: payload(world.space.id, status: "expired", expiresAt: "2026-09-18T10:00:00Z")),
            local: [lapsedTrial]
        )
        let payerView = await payer.refreshResolution(spaceId: world.space.id)
        #expect(payerView == EntitlementResolution(state: .readOnly, readOnlyCause: .trialEnded))

        let stored = try #require(try await world.repositories.spaces.space(id: world.space.id))
        #expect(stored.subscriptionStatus == .trial)
        #expect(stored.subscriptionExpiresAt == endedAt)

        let partner = service(
            world,
            transport: FakeTransport(json: payload(world.space.id, status: "expired", expiresAt: "2026-09-18T10:00:00Z"))
        )
        #expect(await partner.refreshResolution(spaceId: world.space.id).readOnlyCause == .trialEnded)
        #expect(await partner.cachedResolution(space: stored).readOnlyCause == .trialEnded)
        let afterPartner = try await world.repositories.spaces.space(id: world.space.id)
        #expect(afterPartner?.subscriptionStatus == .trial)
    }

    @Test func thePartnerDoesNotOverwriteARunningTrialWithActive() async throws {
        let world = try await TestWorld.make()
        let endsAt = NetTestSupport.date("2026-10-04T10:00:00Z")
        _ = try await world.repositories.spaces.setSubscription(
            spaceId: world.space.id,
            status: .trial,
            expiresAt: endsAt,
            payerMemberId: nil
        )
        let partner = service(world, transport: FakeTransport(json: payload(world.space.id, status: "active", expiresAt: "2026-10-04T10:00:00Z")))
        #expect(await partner.refresh(spaceId: world.space.id) == .premium(source: .server, expiresAt: endsAt))
        let stored = try await world.repositories.spaces.space(id: world.space.id)
        #expect(stored?.subscriptionStatus == .trial)
    }

    @Test func theTrialNoticeIsScheduledTwoDaysBeforeTheStoreKitExpiry() async throws {
        let world = try await TestWorld.make()
        let endsAt = NetTestSupport.date("2026-10-04T10:00:00Z")
        let center = FakeNotificationCenter()
        let trial = SubscriptionTestSupport.record(for: world.space.id, purchasedAt: now, expiresAt: endsAt, isInIntroOffer: true)
        let service = service(
            world,
            transport: FakeTransport(json: payload(world.space.id, status: "none", expiresAt: nil)),
            local: [trial],
            notifications: NotificationScheduler(client: center, calendar: DomainClock.calendar())
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

        let service = service(
            world,
            transport: FakeTransport(json: payload(world.space.id, status: "active", expiresAt: "2027-09-05T10:00:00Z")),
            notifications: scheduler
        )

        _ = await service.refresh(spaceId: world.space.id)
        #expect(await center.requests.isEmpty)
        #expect(await center.removedIdentifiers.contains(NotificationIdentifier.trialEnding))
    }

    @Test func anOfflineRefreshFallsBackToTheKeychainCopy() async throws {
        let world = try await TestWorld.make()
        let secrets = InMemorySecretStore()
        let online = service(
            world,
            transport: FakeTransport(json: payload(world.space.id, status: "active", expiresAt: "2027-09-05T10:00:00Z")),
            secrets: secrets
        )
        _ = await online.refresh(spaceId: world.space.id)

        let offline = service(world, transport: unreachable(), secrets: secrets, at: NetTestSupport.date("2026-09-21T10:00:00Z"), retry: .noRetries)
        let state = await offline.refresh(spaceId: world.space.id)
        #expect(state == .premium(source: .server, expiresAt: NetTestSupport.date("2027-09-05T10:00:00Z")))
    }

    @Test func aKeychainCopyWithoutAnEnvironmentIsIgnored() async throws {
        let world = try await TestWorld.make()
        let secrets = InMemorySecretStore()
        let olderCopy = try CorbieJSON.encoder.encode(
            ServerEntitlement(status: .active, expiresAt: NetTestSupport.date("2027-09-05T10:00:00Z"))
        )
        try secrets.setData(olderCopy, for: EntitlementService.cacheKey(spaceId: world.space.id))
        let offline = service(world, transport: unreachable(), secrets: secrets, retry: .noRetries)
        #expect(await offline.refresh(spaceId: world.space.id) == .readOnly)
    }

    @Test func anUnknownSpaceLeavesTheGateClosed() async throws {
        let world = try await TestWorld.make()
        let service = service(world, transport: FakeTransport(json: payload(world.space.id, status: "none", expiresAt: nil)))
        let resolution = await service.refreshResolution(spaceId: world.space.id)
        #expect(resolution == EntitlementResolution(state: .readOnly, readOnlyCause: .neverSubscribed))
        let stored = try await world.repositories.spaces.space(id: world.space.id)
        #expect(stored?.subscriptionStatus == .readonly)
    }

    @Test func theCachedStateReadsTheKeychainAndTheMirroredSpace() async throws {
        let world = try await TestWorld.make()
        let secrets = InMemorySecretStore()
        let online = service(
            world,
            transport: FakeTransport(json: payload(world.space.id, status: "active", expiresAt: "2027-09-05T10:00:00Z")),
            secrets: secrets
        )
        _ = await online.refresh(spaceId: world.space.id)

        let offline = service(world, transport: unreachable(), secrets: secrets, retry: .noRetries)
        let stored = try #require(try await world.repositories.spaces.space(id: world.space.id))
        #expect(await offline.cachedState(space: stored).isPremium)

        let mirroredOnly = service(world, transport: unreachable(), retry: .noRetries)
        #expect(await mirroredOnly.cachedState(space: stored) == .premium(
            source: .space,
            expiresAt: NetTestSupport.date("2027-09-05T10:00:00Z")
        ))
    }

    @Test func clearingTheCacheForgetsTheServerAnswer() async throws {
        let world = try await TestWorld.make()
        let service = service(world, transport: FakeTransport(json: payload(world.space.id, status: "active", expiresAt: nil)))
        _ = await service.refresh(spaceId: world.space.id)
        #expect(await service.cachedEntitlement(spaceId: world.space.id) != nil)
        await service.clearCache(spaceId: world.space.id)
        #expect(await service.cachedEntitlement(spaceId: world.space.id) == nil)
        #expect(EntitlementService.cacheKey(spaceId: world.space.id).hasPrefix("corbie.entitlement."))
    }

    @Test func onlyAProductionBuildWritesTheMirror() async throws {
        for build in [StubAppTransaction.sandbox, .xcode, .unknown] {
            let world = try await TestWorld.make()
            let active = SubscriptionTestSupport.record(
                for: world.space.id,
                environment: build.environment ?? .production,
                purchasedAt: now,
                expiresAt: NetTestSupport.date("2026-10-20T10:00:00Z")
            )
            let service = service(
                world,
                transport: FakeTransport(json: payload(
                    world.space.id,
                    status: "active",
                    expiresAt: "2026-10-20T10:00:00Z",
                    environment: build.environment == .sandbox ? "Sandbox" : "Production"
                )),
                local: [active],
                appTransaction: build
            )
            #expect(await service.refresh(spaceId: world.space.id).isPremium)
            let stored = try await world.repositories.spaces.space(id: world.space.id)
            #expect(stored?.subscriptionStatus == SubscriptionStatus.none, "a \(String(describing: build.environment)) build wrote the mirror")
            #expect(stored?.subscriptionExpiresAt == nil)
        }
    }

    @Test func aSandboxEntitlementIsNeverPaidInAProductionBuild() async throws {
        let world = try await TestWorld.make()
        let secrets = InMemorySecretStore()
        let sandboxExpiry = "2026-10-20T10:00:00Z"
        let sandboxPurchase = SubscriptionTestSupport.record(
            for: world.space.id,
            environment: .sandbox,
            purchasedAt: now,
            expiresAt: NetTestSupport.date(sandboxExpiry)
        )

        let testFlight = service(
            world,
            transport: FakeTransport(json: payload(world.space.id, status: "active", expiresAt: sandboxExpiry, environment: "Sandbox")),
            secrets: secrets,
            local: [sandboxPurchase],
            appTransaction: .sandbox
        )
        #expect(await testFlight.refresh(spaceId: world.space.id).isPremium)
        #expect(await testFlight.cachedEntitlement(spaceId: world.space.id)?.environment == .sandbox)

        let appStore = service(
            world,
            transport: FakeTransport(json: payload(world.space.id, status: "active", expiresAt: sandboxExpiry, environment: "Sandbox")),
            secrets: secrets,
            local: [sandboxPurchase]
        )
        let online = await appStore.refreshResolution(spaceId: world.space.id)
        #expect(online.state == .readOnly)
        #expect(online.readOnlyCause == .neverSubscribed)

        let offline = service(world, transport: unreachable(), secrets: secrets, local: [sandboxPurchase], retry: .noRetries)
        #expect(await offline.refresh(spaceId: world.space.id) == .readOnly)

        let stored = try #require(try await world.repositories.spaces.space(id: world.space.id))
        #expect(stored.subscriptionStatus == .readonly)
        #expect(await offline.cachedState(space: stored) == .readOnly)
        #expect(WidgetPremiumRule.isPremium(space: stored, now: now, monetizationEnabled: true) == false)
    }

    @Test func anActiveSubscriptionFromAnotherSpaceIsSyncedOncePerTransaction() async throws {
        let world = try await TestWorld.make()
        let secrets = InMemorySecretStore()
        let solo = UUID()
        let bought = SubscriptionTestSupport.record(
            for: solo,
            purchasedAt: now,
            expiresAt: NetTestSupport.date("2026-10-04T10:00:00Z"),
            isInIntroOffer: true,
            transactionId: 7
        )
        let transport = FakeTransport([
            .json(payload(world.space.id, status: "none", expiresAt: nil)),
            .json(payload(world.space.id, status: "active", expiresAt: "2026-10-04T10:00:00Z")),
            .json(payload(world.space.id, status: "active", expiresAt: "2026-10-04T10:00:00Z"))
        ])
        let service = service(world, transport: transport, secrets: secrets, local: [bought])

        let first = await service.refresh(spaceId: world.space.id)
        #expect(first == .premium(source: .server, expiresAt: NetTestSupport.date("2026-10-04T10:00:00Z")))
        let sync = try #require(transport.requests.last)
        #expect(sync.method == .post)
        #expect(sync.url.path.hasSuffix("/entitlement/sync"))
        #expect(sync.headers["X-App-Transaction"] == StubAppTransaction.production.signed)
        let body = try #require(try JSONSerialization.jsonObject(with: sync.body ?? Data()) as? [String: String])
        #expect(body == ["spaceId": world.space.id.uuidString.lowercased(), "signedTransaction": "signed-transaction-7"])

        _ = await service.refresh(spaceId: world.space.id)
        #expect(transport.requests.filter { $0.method == .post }.count == 1)
    }

    @Test func aPurchaseIsSyncedWithItsSignedTransaction() async throws {
        let world = try await TestWorld.make()
        let transport = FakeTransport(json: payload(world.space.id, status: "active", expiresAt: "2026-10-04T10:00:00Z"))
        let service = service(world, transport: transport)
        await service.syncPurchase(signedTransaction: "signed.purchase", spaceId: world.space.id)
        let request = try #require(transport.lastRequest)
        #expect(request.method == .post)
        #expect(request.headers["X-App-Transaction"] == StubAppTransaction.production.signed)
        #expect(await service.cachedEntitlement(spaceId: world.space.id)?.status == .active)
    }

    @Test func restoreSaysWhetherThisAppleIDHasASubscription() async throws {
        let world = try await TestWorld.make()
        let empty = FakeTransport(json: payload(world.space.id, status: "none", expiresAt: nil))
        #expect(await service(world, transport: empty).reconcileAfterRestore(spaceId: world.space.id) == .nothingToRestore)
        #expect(empty.requestCount == 0)

        let own = SubscriptionTestSupport.record(
            for: world.space.id,
            purchasedAt: now,
            expiresAt: NetTestSupport.date("2026-10-20T10:00:00Z")
        )
        let reconciled = FakeTransport(json: payload(world.space.id, status: "active", expiresAt: "2026-10-20T10:00:00Z"))
        #expect(await service(world, transport: reconciled, local: [own]).reconcileAfterRestore(spaceId: world.space.id) == .restored)
        #expect(reconciled.lastRequest?.method == .post)

        let sandboxOnly = SubscriptionTestSupport.record(
            for: world.space.id,
            environment: .sandbox,
            purchasedAt: now,
            expiresAt: NetTestSupport.date("2026-10-20T10:00:00Z")
        )
        let ignored = FakeTransport(json: payload(world.space.id, status: "none", expiresAt: nil))
        #expect(await service(world, transport: ignored, local: [sandboxOnly]).reconcileAfterRestore(spaceId: world.space.id)
            == .nothingToRestore)
        #expect(ignored.requestCount == 0)
    }
}
