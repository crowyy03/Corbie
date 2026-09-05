import CorbieCore
import XCTest
@testable import Corbie

final class SettingsStatusTests: XCTestCase {
    func testTheTrialLineCountsTheDaysLeft() {
        let status = SettingsSubscriptionStatus(state: .trial(daysLeft: 3))
        XCTAssertTrue(status.text.contains("3"), status.text)
        XCTAssertTrue(status.showsPlans)
    }

    func testAnActiveSubscriptionNamesItsEndDate() {
        let expiry = Date(timeIntervalSince1970: 1_800_000_000)
        let status = SettingsSubscriptionStatus(state: .active(source: .server, expiresAt: expiry))
        XCTAssertTrue(status.text.contains(expiry.formatted(date: .abbreviated, time: .omitted)), status.text)
        XCTAssertFalse(status.showsPlans)
    }

    func testAnActiveSubscriptionWithoutAnEndDateStillReadsAsActive() {
        let status = SettingsSubscriptionStatus(state: .active(source: .storeKit, expiresAt: nil))
        XCTAssertEqual(status.text, String(localized: "settings.subscription.active"))
    }

    func testReadOnlyOffersThePlans() {
        let status = SettingsSubscriptionStatus(state: .readOnly)
        XCTAssertEqual(status.text, String(localized: "settings.subscription.readonly"))
        XCTAssertTrue(status.showsPlans)
    }

    func testTheOwnerDeletesTheSpaceAndTheJoinerLeavesIt() {
        let owner = UUID()
        let joiner = UUID()
        let space = SpaceDTO(id: UUID(), creatorMemberId: owner)
        XCTAssertEqual(SettingsAccountPlan.decide(space: space, memberId: owner), .deleteSpace)
        XCTAssertEqual(SettingsAccountPlan.decide(space: space, memberId: joiner), .leaveSpace)
        XCTAssertEqual(SettingsAccountPlan.decide(space: space, memberId: nil), .leaveSpace)
    }

    func testASpaceWithoutACreatorIsDeleted() {
        let space = SpaceDTO(id: UUID())
        XCTAssertEqual(SettingsAccountPlan.decide(space: space, memberId: UUID()), .deleteSpace)
    }

    func testTheLegalPagesPointAtTheHostedDocuments() {
        XCTAssertEqual(SettingsLegalPage.privacy.url?.absoluteString, "https://corbie.app/privacy")
        XCTAssertEqual(SettingsLegalPage.terms.url?.absoluteString, "https://corbie.app/terms")
        for page in SettingsLegalPage.allCases {
            let title = String(localized: String.LocalizationValue(page.titleKey))
            XCTAssertNotEqual(title, page.titleKey)
        }
    }
}
