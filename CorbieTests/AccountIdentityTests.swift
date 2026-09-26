import CorbieCore
import XCTest
@testable import Corbie

final class AccountIdentityTests: XCTestCase {
    @MainActor
    func testAnAppleUserIdThatNoMemberUsesIsForgottenOnSessionLoad() async throws {
        let environment = makeEnvironment()
        try environment.storeAppleCredential(userIdentifier: "debug.simulator.user", identityToken: nil)

        await environment.reloadSession()

        XCTAssertEqual(environment.session, .signedOut)
        XCTAssertNil(environment.identity.currentAppleUserID)
    }

    @MainActor
    func testTheAppleUserIdOfTheMemberOnThisPhoneStays() async throws {
        let environment = makeEnvironment()
        let space = try await environment.repositories.spaces.create(displayCurrency: "USD", creatorMemberId: nil, now: Date())
        _ = try await environment.repositories.members.upsertCurrentMember(
            appleUserId: "000123.real.user",
            spaceId: space.id,
            draft: MemberDraft(displayName: "Anna"),
            theme: environment.theme.activeTheme
        )
        try environment.storeAppleCredential(userIdentifier: "000123.real.user", identityToken: nil)

        await environment.reloadSession()

        XCTAssertTrue(environment.isSignedIn)
        XCTAssertEqual(environment.identity.currentAppleUserID, "000123.real.user")
    }

    func testTheCredentialCheckNamesEveryState() {
        XCTAssertEqual(AppleCredentialMonitor.name(of: .authorized), "authorized")
        XCTAssertEqual(AppleCredentialMonitor.name(of: .revoked), "revoked")
        XCTAssertEqual(AppleCredentialMonitor.name(of: .notFound), "not found")
        XCTAssertEqual(AppleCredentialMonitor.name(of: .transferred), "transferred")
    }

    @MainActor
    private func makeEnvironment() -> AppEnvironment {
        AppEnvironment(
            persistence: PersistenceController.inMemory(),
            secrets: InMemorySecretStore(),
            anonymousIdentity: .inMemory(),
            notificationClient: PreviewNotificationClient(),
            transport: OfflineAccountTransport()
        )
    }
}

#if DEBUG
final class DebugMenuStatusTests: XCTestCase {
    func testAForcedStateSaysWhetherItIsInEffect() {
        XCTAssertEqual(
            DebugMenuStatus.overrideLine(.trialEnded, monetizationOn: true),
            "forced: trial_ended, in effect"
        )
        XCTAssertEqual(
            DebugMenuStatus.overrideLine(.premium, monetizationOn: false),
            "forced: premium, ignored while monetization is off"
        )
    }

    func testTheSubscriptionRowsCoverBothEndedStates() {
        let overrides = DebugMenuEntitlementRow.all.map(\.override)
        XCTAssertTrue(overrides.contains(.trialEnded))
        XCTAssertTrue(overrides.contains(.subscriptionEnded))
        XCTAssertFalse(overrides.contains(.readOnly))
    }
}
#endif

private struct OfflineAccountTransport: HTTPTransport {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        throw URLError(.notConnectedToInternet)
    }
}
