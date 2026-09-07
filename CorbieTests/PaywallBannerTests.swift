import CorbieCore
import XCTest
@testable import Corbie

final class PaywallBannerTests: XCTestCase {
    private func trial(daysLeft: Int) -> EntitlementState {
        .trial(daysLeft: daysLeft, endsAt: Date().addingTimeInterval(Double(daysLeft) * 86_400))
    }

    func testTheBannerAppearsOnlyInTheLastTwoTrialDays() {
        XCTAssertNil(PaywallBannerState.make(trial(daysLeft: 14)))
        XCTAssertNil(PaywallBannerState.make(trial(daysLeft: 3)))
        XCTAssertEqual(PaywallBannerState.make(trial(daysLeft: 2)), .trialEnding(daysLeft: 2))
        XCTAssertEqual(PaywallBannerState.make(trial(daysLeft: 1)), .trialEnding(daysLeft: 1))
    }

    func testAPayingCoupleNeverSeesTheBanner() {
        XCTAssertNil(PaywallBannerState.make(.premium(source: .server, expiresAt: nil)))
        XCTAssertNil(PaywallBannerState.make(.premium(source: .storeKit, expiresAt: Date())))
        XCTAssertNil(PaywallBannerState.make(.grace(expiresAt: nil)))
    }

    func testReadOnlyKeepsTheBannerUp() {
        XCTAssertEqual(PaywallBannerState.make(.readOnly), .readOnly)
        XCTAssertNil(PaywallBannerState.readOnly.daysLeft)
        XCTAssertEqual(PaywallBannerState.trialEnding(daysLeft: 2).daysLeft, 2)
        XCTAssertEqual(PaywallBannerState.readOnly.reason, .trialEnded)
        XCTAssertEqual(PaywallBannerState.trialEnding(daysLeft: 2).reason, .trialEnding)
    }

    func testTheSpokenBannerCarriesTheDayCount() {
        XCTAssertEqual(PaywallBannerState.trialEnding(daysLeft: 2).message, "Trial ends soon.")
        XCTAssertEqual(PaywallBannerState.trialEnding(daysLeft: 2).spokenMessage, "2 days left in your trial")
        XCTAssertEqual(PaywallBannerState.trialEnding(daysLeft: 1).spokenMessage, "1 day left in your trial")
        XCTAssertEqual(PaywallBannerState.readOnly.message, "Trial over. The calendar and Today still work.")
        XCTAssertEqual(PaywallBannerState.readOnly.spokenMessage, PaywallBannerState.readOnly.message)
        XCTAssertNotEqual(String(localized: "paywall.banner.action"), "paywall.banner.action")
    }
}
