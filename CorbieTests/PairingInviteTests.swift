import CorbieCore
import XCTest
@testable import Corbie

final class PairingInviteTests: XCTestCase {
    func testSanitizeUppercasesAndDropsCharactersOutsideTheAlphabet() {
        XCTAssertEqual(InviteCodeFormat.sanitize("k7m2qx"), "K7M2QX")
        XCTAssertEqual(InviteCodeFormat.sanitize("k7-m2 qx"), "K7M2QX")
        XCTAssertEqual(InviteCodeFormat.sanitize("IL01O"), "")
    }

    func testSanitizeStopsAtSixCharacters() {
        XCTAssertEqual(InviteCodeFormat.sanitize("K7M2QXABC"), "K7M2QX")
        XCTAssertEqual(InviteCodeFormat.sanitize("K7M2QX").count, InviteCodeFormat.length)
    }

    func testCompletenessNeedsSixUsableCharacters() {
        XCTAssertTrue(InviteCodeFormat.isComplete("k7m2qx"))
        XCTAssertFalse(InviteCodeFormat.isComplete("K7M2Q"))
        XCTAssertFalse(InviteCodeFormat.isComplete("K7M2QI"))
        XCTAssertFalse(InviteCodeFormat.isComplete(""))
    }

    func testAlphabetLeavesOutTheAmbiguousLettersAndDigits() {
        for character in "IL10O" {
            XCTAssertFalse(InviteCodeFormat.alphabet.contains(character))
        }
    }

    func testSpelledOutSeparatesCharactersForVoiceOver() {
        XCTAssertEqual(InviteCodeFormat.spelledOut("K7M2QX"), "K 7 M 2 Q X")
    }

    func testSharedLinkParsesBackIntoAJoinRoute() throws {
        let url = try XCTUnwrap(InviteLink.url(code: "K7M2QX"))
        XCTAssertEqual(url.absoluteString, "https://corbie.app/join/K7M2QX")
        XCTAssertEqual(Router.route(for: url), .join("K7M2QX"))
    }

    func testSharedLinkNeedsACode() {
        XCTAssertNil(InviteLink.url(code: ""))
        XCTAssertEqual(InviteLink.message(code: ""), "")
    }

    func testCountdownCountsDownToZero() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let expiresAt = now.addingTimeInterval(15 * 60)

        XCTAssertEqual(InviteCountdown(expiresAt: expiresAt, now: now).text(locale: .posix), "15:00")
        XCTAssertEqual(
            InviteCountdown(expiresAt: expiresAt, now: now.addingTimeInterval(1)).text(locale: .posix),
            "14:59"
        )
        XCTAssertEqual(
            InviteCountdown(expiresAt: expiresAt, now: now.addingTimeInterval(15 * 60 - 61)).text(locale: .posix),
            "1:01"
        )
    }

    func testCountdownClampsAtZeroOnceItExpired() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let countdown = InviteCountdown(expiresAt: now.addingTimeInterval(-30), now: now)

        XCTAssertTrue(countdown.isExpired)
        XCTAssertEqual(countdown.remaining, 0)
        XCTAssertEqual(countdown.text(locale: .posix), "0:00")
    }

    func testCountdownIsNotExpiredWithASecondLeft() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let countdown = InviteCountdown(expiresAt: now.addingTimeInterval(1), now: now)

        XCTAssertFalse(countdown.isExpired)
        XCTAssertEqual(countdown.text(locale: .posix), "0:01")
    }

    func testJoinFailureNamesWhatTheServerSaid() {
        XCTAssertEqual(JoinFailure.kind(for: serverError(status: 404, code: "not_found")), .notFound)
        XCTAssertEqual(JoinFailure.kind(for: serverError(status: 410, code: "expired")), .expired)
        XCTAssertEqual(JoinFailure.kind(for: serverError(status: 410, code: "redeemed")), .redeemed)
        XCTAssertEqual(JoinFailure.kind(for: serverError(status: 429, code: "rate_limited")), .throttled)
        XCTAssertEqual(JoinFailure.kind(for: CorbieError.cloudKit("no account")), .iCloud)
        XCTAssertEqual(JoinFailure.kind(for: CorbieError.network("offline")), .generic)
    }

    func testSessionExchangeSeparatesAuthFromNetworkFailures() {
        XCTAssertEqual(SessionService.failure(status: 401, body: Data()), .auth("status 401"))
        XCTAssertEqual(SessionService.failure(status: 500, body: Data()), .network("status 500"))

        let envelope = Data(#"{"error":"unauthorized","message":"token expired"}"#.utf8)
        XCTAssertEqual(SessionService.failure(status: 403, body: envelope), .auth("token expired"))
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private let suiteName = "app.corbie.tests.pairing"

    private func serverError(status: Int, code: String) -> APIError {
        APIError(
            kind: .server,
            status: status,
            envelope: ServerErrorEnvelope(error: code, message: "server said \(code)"),
            detail: code
        )
    }
}

private extension Locale {
    static let posix = Locale(identifier: "en_US_POSIX")
}
