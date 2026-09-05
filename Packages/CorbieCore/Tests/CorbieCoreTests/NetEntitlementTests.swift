import Foundation
import Testing
@testable import CorbieCore

@Suite struct NetEntitlementResolverTests {
    private let now = NetTestSupport.date("2026-09-05T10:00:00Z")

    private func inputs(
        trialEndsAt: Date? = nil,
        server: ServerEntitlement? = nil,
        local: LocalEntitlement? = nil
    ) -> EntitlementInputs {
        EntitlementInputs(trialEndsAt: trialEndsAt, server: server, local: local, now: now)
    }

    @Test func aFreshSpaceIsInTrial() {
        let state = EntitlementResolver.resolve(inputs(trialEndsAt: now.addingTimeInterval(7 * 86_400)))
        #expect(state == .trial(daysLeft: 7))
        #expect(state.isPremium)
        #expect(state.isReadOnly == false)
        #expect(state.trialDaysLeft == 7)
    }

    @Test func anExpiredTrialWithoutAnEntitlementIsReadOnly() {
        let state = EntitlementResolver.resolve(inputs(trialEndsAt: now.addingTimeInterval(-1)))
        #expect(state == .readOnly)
        #expect(state.isPremium == false)
        #expect(state.trialDaysLeft == nil)
    }

    @Test func anExpiredTrialWithAnActiveServerEntitlementIsActive() {
        let expiry = now.addingTimeInterval(300 * 86_400)
        let state = EntitlementResolver.resolve(
            inputs(
                trialEndsAt: now.addingTimeInterval(-86_400),
                server: ServerEntitlement(status: .active, productId: "app.corbie.yearly", expiresAt: expiry)
            )
        )
        #expect(state == .active(source: .server, expiresAt: expiry))
        #expect(state.isPremium)
        #expect(state.expiresAt == expiry)
    }

    @Test func thePartnerDeviceHasNoTransactionsAndStillGetsAccess() {
        let state = EntitlementResolver.resolve(
            inputs(server: ServerEntitlement(status: .active, expiresAt: now.addingTimeInterval(86_400)), local: nil)
        )
        #expect(state == .active(source: .server, expiresAt: now.addingTimeInterval(86_400)))
    }

    @Test func theBuyerDeviceUsesItsOwnTransactionWhenTheServerKnowsNothing() {
        let expiry = now.addingTimeInterval(30 * 86_400)
        let state = EntitlementResolver.resolve(
            inputs(
                server: ServerEntitlement(status: .none),
                local: LocalEntitlement(productId: "app.corbie.monthly", expiresAt: expiry)
            )
        )
        #expect(state == .active(source: .storeKit, expiresAt: expiry))
    }

    @Test func aServerEntitlementPastItsExpiryIsNotActive() {
        let state = EntitlementResolver.resolve(
            inputs(server: ServerEntitlement(status: .active, expiresAt: now.addingTimeInterval(-1)))
        )
        #expect(state == .readOnly)
    }

    @Test func gracePeriodKeepsAccess() {
        let expiry = now.addingTimeInterval(-86_400)
        let state = EntitlementResolver.resolve(inputs(server: ServerEntitlement(status: .grace, expiresAt: expiry)))
        #expect(state == .grace(expiresAt: expiry))
        #expect(state.isPremium)
    }

    @Test func aRefundBeatsAnyLocalTransaction() {
        let state = EntitlementResolver.resolve(
            inputs(
                trialEndsAt: now.addingTimeInterval(5 * 86_400),
                server: ServerEntitlement(status: .revoked),
                local: LocalEntitlement(productId: "app.corbie.yearly", expiresAt: now.addingTimeInterval(86_400))
            )
        )
        #expect(state == .readOnly)
    }

    @Test func aRevokedLocalTransactionIsIgnored() {
        let state = EntitlementResolver.resolve(
            inputs(local: LocalEntitlement(productId: "app.corbie.yearly", expiresAt: nil, isRevoked: true))
        )
        #expect(state == .readOnly)
    }

    @Test func aPaidSubscriptionOutranksARunningTrial() {
        let expiry = now.addingTimeInterval(360 * 86_400)
        let state = EntitlementResolver.resolve(
            inputs(
                trialEndsAt: now.addingTimeInterval(3 * 86_400),
                server: ServerEntitlement(status: .active, expiresAt: expiry)
            )
        )
        #expect(state == .active(source: .server, expiresAt: expiry))
    }

    @Test func theTrialBoundaryIsExclusive() {
        #expect(EntitlementResolver.trialDaysLeft(endsAt: now, now: now) == nil)
        #expect(EntitlementResolver.trialDaysLeft(endsAt: now.addingTimeInterval(-1), now: now) == nil)
        #expect(EntitlementResolver.trialDaysLeft(endsAt: now.addingTimeInterval(1), now: now) == 1)
        #expect(EntitlementResolver.trialDaysLeft(endsAt: now.addingTimeInterval(86_400), now: now) == 1)
        #expect(EntitlementResolver.trialDaysLeft(endsAt: now.addingTimeInterval(86_401), now: now) == 2)
        #expect(EntitlementResolver.trialDaysLeft(endsAt: now.addingTimeInterval(7 * 86_400), now: now) == 7)
        #expect(EntitlementResolver.trialDaysLeft(endsAt: nil, now: now) == nil)
    }

    @Test func theMirroredStatusTellsAnExpiredSubscriptionFromAnExpiredTrial() {
        #expect(EntitlementService.mirroredStatus(.trial(daysLeft: 3), server: nil) == .trial)
        #expect(EntitlementService.mirroredStatus(.active(source: .server, expiresAt: nil), server: nil) == .active)
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
        #expect(state == .active(source: .server, expiresAt: NetTestSupport.date("2027-09-05T10:00:00Z")))
        #expect(await service.state == state)

        let cached = await service.cachedEntitlement(spaceId: world.space.id)
        #expect(cached?.status == .active)
        #expect(cached?.productId == "app.corbie.yearly")

        let stored = try await world.repositories.spaces.space(id: world.space.id)
        #expect(stored?.subscriptionStatus == .active)
        #expect(stored?.subscriptionExpiresAt == NetTestSupport.date("2027-09-05T10:00:00Z"))
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
        #expect(state == .active(source: .server, expiresAt: NetTestSupport.date("2027-09-05T10:00:00Z")))
    }

    @Test func anUnknownSpaceLeavesTheTrialRunning() async throws {
        let world = try await TestWorld.make()
        let service = EntitlementService(
            client: NetTestSupport.client(transport: FakeTransport(json: payload(world.space.id, status: "none", expiresAt: nil))),
            spaces: world.repositories.spaces,
            store: InMemorySecretStore(),
            now: { NetTestSupport.date("2026-09-05T10:00:00Z") }
        )
        let state = await service.refresh(spaceId: world.space.id)
        #expect(state.isPremium)
        #expect(state.trialDaysLeft != nil)
        let stored = try await world.repositories.spaces.space(id: world.space.id)
        #expect(stored?.subscriptionStatus == .trial)
    }

    @Test func theSecondMemberGetsAFullWeekAgain() async throws {
        let world = try await TestWorld.make()
        let joinedAt = NetTestSupport.date("2026-09-09T10:00:00Z")
        let service = EntitlementService(
            client: NetTestSupport.client(transport: FakeTransport(json: payload(world.space.id, status: "none", expiresAt: nil))),
            spaces: world.repositories.spaces,
            store: InMemorySecretStore(),
            now: { joinedAt }
        )
        let before = try #require(try await world.repositories.spaces.space(id: world.space.id))
        let extended = try await service.extendTrialForSecondMember(space: before)
        #expect(extended.trialEndsAt == joinedAt.addingTimeInterval(7 * 86_400))
        #expect(extended.trialActive(at: joinedAt))

        let again = try await service.extendTrialForSecondMember(space: extended)
        #expect(again.trialEndsAt == extended.trialEndsAt)
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
