import CloudKit
import CorbieCore
import XCTest
@testable import Corbie

final class PairingRecoveryTests: XCTestCase {
    private let suiteName = "app.corbie.tests.pairing.recovery"

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    @MainActor
    func testANewCodeAfterAFailedJoinAsksTheServerAgain() async throws {
        var asked: [String] = []
        let redemption = InviteRedemption { code in
            asked.append(code)
            return InviteShare(shareURL: "https://www.icloud.com/share/\(code)", spaceId: UUID())
        }

        let dead = try await redemption.share(for: "FYDW7C")
        let retried = try await redemption.share(for: "FYDW7C")
        let fresh = try await redemption.share(for: "JHQ6FU")

        XCTAssertEqual(asked, ["FYDW7C", "JHQ6FU"])
        XCTAssertEqual(retried, dead)
        XCTAssertEqual(fresh.shareURL, "https://www.icloud.com/share/JHQ6FU")
    }

    @MainActor
    func testARefusedRedeemIsNotRemembered() async throws {
        var answers: [Result<InviteShare, any Error>] = [
            .failure(URLError(.notConnectedToInternet)),
            .success(InviteShare(shareURL: "https://www.icloud.com/share/abc", spaceId: UUID()))
        ]
        let redemption = InviteRedemption { _ in try answers.removeFirst().get() }

        do {
            _ = try await redemption.share(for: "FYDW7C")
            XCTFail("expected the first redeem to fail")
        } catch {}
        let share = try await redemption.share(for: "FYDW7C")
        XCTAssertEqual(share.shareURL, "https://www.icloud.com/share/abc")
        XCTAssertTrue(answers.isEmpty)
    }

    func testAGoneShareTellsTheJoinerToAskForANewCodeAndTheOwnerTheCode() {
        let gone = CloudKitFailure(step: "fetch share metadata", error: CKError(.unknownItem))

        XCTAssertEqual(PairingFailure.kind(for: gone, side: .joining), .shareMissing)
        XCTAssertEqual(PairingFailure.message(for: gone, side: .joining), PairingFailure.shareMissing.message)
        XCTAssertEqual(PairingFailure.kind(for: gone, side: .inviting), .iCloudRefused)
        XCTAssertTrue(PairingFailure.message(for: gone, side: .inviting).contains("11"))
    }

    func testAnyOtherCloudKitRefusalShowsItsCode() {
        let refused = CloudKitFailure(step: "fetch share metadata", error: CKError(.permissionFailure))
        let message = PairingFailure.message(for: refused, side: .joining)

        XCTAssertTrue(message.contains("10"), message)
        XCTAssertNotEqual(message, PairingFailure.shareMissing.message)
        XCTAssertFalse(message.hasPrefix("pairing."))
    }

    func testTheServerNamesAnotherBuildAndTheSameAccount() {
        XCTAssertEqual(PairingFailure.kind(for: refusal("environment_mismatch"), side: .joining), .environmentMismatch)
        XCTAssertEqual(PairingFailure.kind(for: refusal("same_icloud_account"), side: .joining), .ownAccount)
        XCTAssertNotEqual(PairingFailure.environmentMismatch.message, PairingFailure.ownAccount.message)
    }

    func testTheNewCopyUsesAPeriodAndNoDash() {
        for failure in [PairingFailure.shareMissing, .ownAccount, .environmentMismatch, .iCloudRefused, .iCloudFull] {
            XCTAssertFalse(failure.message.contains("\u{2014}"), failure.rawValue)
            XCTAssertTrue(failure.message.hasSuffix("."), failure.rawValue)
        }
    }

    @MainActor
    func testWipingTheAccountForgetsTheLiveInviteCode() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let environment = AppEnvironment(
            persistence: PersistenceController.inMemory(),
            secrets: InMemorySecretStore(),
            anonymousIdentity: .inMemory(),
            notificationClient: PreviewNotificationClient(),
            defaults: defaults
        )
        let spaceId = UUID()
        let store = LiveInviteStore(defaults: defaults)
        store.save(LiveInvite(code: "K7M2QX", expiresAt: Date().addingTimeInterval(600), spaceId: spaceId, existingPartnerId: nil))

        await environment.wipeLocalState()

        XCTAssertNil(store.live(for: spaceId, at: Date()))
    }

    private func refusal(_ code: String) -> APIError {
        APIError(
            kind: .server,
            status: 409,
            envelope: ServerErrorEnvelope(error: code, message: "server said \(code)"),
            detail: code
        )
    }
}
