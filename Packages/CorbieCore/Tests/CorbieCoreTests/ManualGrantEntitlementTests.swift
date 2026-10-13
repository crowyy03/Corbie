import Foundation
import Testing
@testable import CorbieCore

@Suite struct ManualGrantEntitlementTests {
    private let spaceId = UUID(uuidString: "1C2B8E3A-4D5F-4A6B-8C7D-9E0F1A2B3C4D") ?? UUID()
    private let now = Date(timeIntervalSince1970: 1_791_000_000)
    private let year2099 = Date(timeIntervalSince1970: 4_102_401_600)

    private var grantAnswer: Data {
        Data("""
        {"spaceId":"1c2b8e3a-4d5f-4a6b-8c7d-9e0f1a2b3c4d","environment":"Production","status":"active",\
        "productId":"manual_grant","expiresAt":"2099-12-31T12:00:00+00:00",\
        "updatedAt":"2026-10-13T10:00:00.123456+00:00"}
        """.utf8)
    }

    private func server() throws -> ServerEntitlement {
        ServerEntitlement(payload: try CorbieJSON.decoder.decode(EntitlementPayload.self, from: grantAnswer))
    }

    @Test func theServersAnswerForAManualGrantDecodes() throws {
        let server = try server()
        #expect(server.status == .active)
        #expect(server.productId == "manual_grant")
        #expect(server.environment == .production)
        #expect(server.expiresAt == year2099)
    }

    @Test func anAppStoreBuildReadsTheGrantAsPremiumFromTheServer() throws {
        let resolution = EntitlementResolver.resolution(
            EntitlementInputs(environment: .production, server: try server(), now: now)
        )
        #expect(resolution.state == .premium(source: .server, expiresAt: year2099))
        #expect(resolution.state.isPremium)
        #expect(resolution.readOnlyCause == nil)
        #expect(EntitlementService.mirroredStatus(resolution) == .active)
    }

    @Test func aSandboxBuildDoesNotReadAProductionGrant() throws {
        let state = EntitlementResolver.resolve(EntitlementInputs(environment: .sandbox, server: try server(), now: now))
        #expect(state == .readOnly)
    }

    @Test func aRefundedPurchaseOnThePhoneStillWinsOverTheGrant() throws {
        let revoked = LocalEntitlement(productId: "app.corbie.monthly", renewal: .revoked)
        let state = EntitlementResolver.resolve(
            EntitlementInputs(environment: .production, local: revoked, server: try server(), now: now)
        )
        #expect(state == .readOnly)
    }

    @Test func bothWidgetPathsShowTheGrantAsPremium() throws {
        let mirrored = SpaceDTO(id: spaceId, subscriptionStatus: .active, subscriptionExpiresAt: year2099)
        #expect(WidgetPremiumRule.isPremium(space: mirrored, now: now, monetizationEnabled: true, freeWindow: nil))

        let suite = "corbie-manual-grant-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let device = DeviceEntitlementStore(defaults: defaults)
        device.record(.premium(source: .server, expiresAt: year2099), spaceId: spaceId, environment: .production, now: now)
        let snapshot = try #require(device.snapshot(spaceId: spaceId, at: now))
        #expect(snapshot.premiumUntil == year2099)
        let unmirrored = SpaceDTO(id: spaceId)
        #expect(
            WidgetPremiumRule.isPremium(
                space: unmirrored,
                now: now,
                monetizationEnabled: true,
                freeWindow: nil,
                device: snapshot,
                environment: .production
            )
        )
    }

    @Test func aRevokedGrantTakesPremiumAwayOnThePhoneAndInTheSpaceTheWidgetsRead() async throws {
        let world = try await TestWorld.make()
        let suite = "corbie-manual-revoke-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let device = DeviceEntitlementStore(defaults: defaults)
        let secrets = InMemorySecretStore()

        let granted = service(world, answer: answer(world.space.id, status: "active", expiresAt: "2099-12-31T12:00:00+00:00"), secrets: secrets, device: device)
        #expect(await granted.refresh(spaceId: world.space.id) == .premium(source: .server, expiresAt: year2099))
        let mirrored = try #require(try await world.repositories.spaces.space(id: world.space.id))
        #expect(mirrored.subscriptionStatus == .active)
        #expect(mirrored.subscriptionExpiresAt == year2099)

        let revoked = service(world, answer: answer(world.space.id, status: "revoked", expiresAt: "2026-10-13T10:00:00+00:00"), secrets: secrets, device: device)
        #expect(await revoked.refresh(spaceId: world.space.id) == .readOnly)
        let after = try #require(try await world.repositories.spaces.space(id: world.space.id))
        #expect(after.subscriptionStatus == .expired)
        #expect(device.snapshot(spaceId: world.space.id, at: now) == nil)
        #expect(WidgetPremiumRule.isPremium(space: after, now: now, monetizationEnabled: true, freeWindow: nil) == false)
    }

    private func answer(_ spaceId: UUID, status: String, expiresAt: String) -> String {
        """
        {"spaceId":"\(spaceId.uuidString.lowercased())","environment":"Production","status":"\(status)",\
        "productId":"manual_grant","expiresAt":"\(expiresAt)","updatedAt":"2026-10-13T10:00:00+00:00"}
        """
    }

    private func service(_ world: TestWorld, answer: String, secrets: InMemorySecretStore, device: DeviceEntitlementStore) -> EntitlementService {
        EntitlementService(
            client: NetTestSupport.client(transport: FakeTransport(json: answer)),
            spaces: world.repositories.spaces,
            monetization: FixedMonetization(isEnabled: true),
            store: secrets,
            local: StubLocalEntitlements([]),
            appTransaction: StubAppTransaction.production,
            device: device,
            now: { now }
        )
    }
}
