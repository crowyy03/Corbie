import CorbieCore
import XCTest
@testable import Corbie

final class PaywallBannerTests: XCTestCase {
    private func trial(daysLeft: Int) -> EntitlementState {
        .trial(daysLeft: daysLeft, endsAt: Date().addingTimeInterval(Double(daysLeft) * 86_400))
    }

    func testTheBannerAppearsOnlyInTheLastTwoTrialDays() {
        XCTAssertNil(PaywallBannerState.make(trial(daysLeft: 14), cause: nil))
        XCTAssertNil(PaywallBannerState.make(trial(daysLeft: 3), cause: nil))
        XCTAssertEqual(PaywallBannerState.make(trial(daysLeft: 2), cause: nil), .trialEnding(daysLeft: 2))
        XCTAssertEqual(PaywallBannerState.make(trial(daysLeft: 1), cause: nil), .trialEnding(daysLeft: 1))
    }

    func testAPayingCoupleNeverSeesTheBanner() {
        XCTAssertNil(PaywallBannerState.make(.premium(source: .server, expiresAt: nil), cause: nil))
        XCTAssertNil(PaywallBannerState.make(.premium(source: .storeKit, expiresAt: Date()), cause: nil))
        XCTAssertNil(PaywallBannerState.make(.grace(expiresAt: nil), cause: .trialEnded))
    }

    func testReadOnlyKeepsTheBannerUp() {
        XCTAssertEqual(PaywallBannerState.make(.readOnly, cause: .trialEnded), .readOnly(.trialEnded))
        XCTAssertEqual(PaywallBannerState.make(.readOnly, cause: nil), .readOnly(.neverSubscribed))
        XCTAssertNil(PaywallBannerState.readOnly(.subscriptionEnded).daysLeft)
        XCTAssertEqual(PaywallBannerState.trialEnding(daysLeft: 2).daysLeft, 2)
        XCTAssertEqual(PaywallBannerState.readOnly(.trialEnded).reason, .readOnly)
        XCTAssertEqual(PaywallBannerState.trialEnding(daysLeft: 2).reason, .trialEnding)
    }

    func testTheReadOnlyBannerSaysWhatHappened() {
        XCTAssertEqual(
            PaywallBannerState.readOnly(.neverSubscribed).message,
            "No subscription yet. The calendar and Today are free."
        )
        XCTAssertEqual(
            PaywallBannerState.readOnly(.subscriptionEnded).message,
            "Subscription ended. The calendar and Today still work."
        )
        XCTAssertEqual(PaywallBannerState.readOnly(.trialEnded).message, "Trial over. The calendar and Today still work.")
        for cause in ReadOnlyCause.allCases {
            let key = PaywallBannerState.readOnlyKey(cause)
            XCTAssertNotEqual(PaywallCopy.text(key), key, "missing catalog value for \(key)")
            XCTAssertEqual(PaywallBannerState.readOnly(cause).spokenMessage, PaywallBannerState.readOnly(cause).message)
        }
    }

    func testTheSpokenBannerCarriesTheDayCount() {
        XCTAssertEqual(PaywallBannerState.trialEnding(daysLeft: 2).message, "Trial ends soon.")
        XCTAssertEqual(PaywallBannerState.trialEnding(daysLeft: 2).spokenMessage, "2 days left in your trial")
        XCTAssertEqual(PaywallBannerState.trialEnding(daysLeft: 1).spokenMessage, "1 day left in your trial")
        XCTAssertNotEqual(String(localized: "paywall.banner.action"), "paywall.banner.action")
    }
}
