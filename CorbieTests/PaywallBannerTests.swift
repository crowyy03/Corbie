import CorbieCore
import XCTest
@testable import Corbie

final class PaywallBannerTests: XCTestCase {
    func testTheBannerAppearsOnlyInTheLastTwoTrialDays() {
        XCTAssertNil(PaywallBannerState.make(.trial(daysLeft: 7)))
        XCTAssertNil(PaywallBannerState.make(.trial(daysLeft: 3)))
        XCTAssertEqual(PaywallBannerState.make(.trial(daysLeft: 2)), .trialEnding(daysLeft: 2))
        XCTAssertEqual(PaywallBannerState.make(.trial(daysLeft: 1)), .trialEnding(daysLeft: 1))
    }

    func testAPayingCoupleNeverSeesTheBanner() {
        XCTAssertNil(PaywallBannerState.make(.active(source: .server, expiresAt: nil)))
        XCTAssertNil(PaywallBannerState.make(.active(source: .storeKit, expiresAt: Date())))
        XCTAssertNil(PaywallBannerState.make(.grace(expiresAt: nil)))
    }

    func testReadOnlyKeepsTheBannerUp() {
        XCTAssertEqual(PaywallBannerState.make(.readOnly), .readOnly)
        XCTAssertEqual(PaywallBannerState.readOnly.daysLeft, 0)
        XCTAssertEqual(PaywallBannerState.readOnly.reason, .trialEnded)
        XCTAssertEqual(PaywallBannerState.trialEnding(daysLeft: 2).reason, .trialEnding)
    }

    func testTheSpokenBannerCarriesTheDayCount() {
        XCTAssertEqual(PaywallBannerState.trialEnding(daysLeft: 2).message, "Trial ends soon.")
        XCTAssertEqual(PaywallBannerState.trialEnding(daysLeft: 2).spokenMessage, "2 days left in your trial")
        XCTAssertEqual(PaywallBannerState.trialEnding(daysLeft: 1).spokenMessage, "1 day left in your trial")
        XCTAssertEqual(PaywallBannerState.readOnly.message, "Trial over. The calendar still works.")
        XCTAssertEqual(PaywallBannerState.readOnly.spokenMessage, PaywallBannerState.readOnly.message)
        XCTAssertNotEqual(String(localized: "paywall.banner.action"), "paywall.banner.action")
    }

    func testTheTrialIsReportedOncePerSpace() {
        XCTAssertTrue(TrialStartReporter.shouldRecord(state: .trial(daysLeft: 7), wasRecorded: false))
        XCTAssertFalse(TrialStartReporter.shouldRecord(state: .trial(daysLeft: 7), wasRecorded: true))
        XCTAssertFalse(TrialStartReporter.shouldRecord(state: .readOnly, wasRecorded: false))
        XCTAssertFalse(TrialStartReporter.shouldRecord(state: .active(source: .server, expiresAt: nil), wasRecorded: false))
    }

    func testTheTrialFlagIsKeyedBySpace() {
        let first = UUID()
        let second = UUID()
        XCTAssertEqual(TrialStartReporter.key(first), "corbie.trial.started." + first.uuidString.lowercased())
        XCTAssertNotEqual(TrialStartReporter.key(first), TrialStartReporter.key(second))
    }
}
