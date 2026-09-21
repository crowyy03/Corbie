import CorbieCore
import XCTest
@testable import Corbie

final class SettingsStatusTests: XCTestCase {
    func testTheTrialLineCountsTheDaysLeft() {
        let status = SettingsSubscriptionStatus(state: .trial(daysLeft: 3, endsAt: Date(timeIntervalSince1970: 1_800_000_000)))
        XCTAssertTrue(status.text.contains("3"), status.text)
        XCTAssertTrue(status.showsPlans)
    }

    func testAnActiveSubscriptionNamesItsEndDate() {
        let expiry = Date(timeIntervalSince1970: 1_800_000_000)
        let status = SettingsSubscriptionStatus(state: .premium(source: .server, expiresAt: expiry))
        XCTAssertTrue(status.text.contains(expiry.formatted(date: .abbreviated, time: .omitted)), status.text)
        XCTAssertFalse(status.showsPlans)
    }

    func testAnActiveSubscriptionWithoutAnEndDateStillReadsAsActive() {
        let status = SettingsSubscriptionStatus(state: .premium(source: .storeKit, expiresAt: nil))
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

    func testOnlyTheJoinerIsOfferedLeaving() {
        let owner = UUID()
        let joiner = UUID()
        let space = SpaceDTO(id: UUID(), creatorMemberId: owner, memberCount: 2)
        XCTAssertFalse(SettingsAccountPlan.offersLeaving(space: space, memberId: owner))
        XCTAssertTrue(SettingsAccountPlan.offersLeaving(space: space, memberId: joiner))
        XCTAssertFalse(SettingsAccountPlan.offersLeaving(space: space, memberId: nil))
        XCTAssertFalse(SettingsAccountPlan.offersLeaving(space: nil, memberId: joiner))
        XCTAssertFalse(SettingsAccountPlan.offersLeaving(space: SpaceDTO(id: UUID()), memberId: joiner))
    }

    func testTheLegalPagesPointAtTheHostedDocuments() {
        XCTAssertEqual(LegalPage.privacy.url?.absoluteString, "https://yourcorbie.app/privacy")
        XCTAssertEqual(LegalPage.terms.url?.absoluteString, "https://yourcorbie.app/terms")
        for page in LegalPage.allCases {
            let title = String(localized: String.LocalizationValue(page.settingsTitleKey))
            XCTAssertNotEqual(title, page.settingsTitleKey)
        }
    }

    @MainActor
    func testAPendingNameEditSurvivesASessionReload() throws {
        let environment = AppEnvironment.previewSignedIn()
        let model = SettingsViewModel()
        model.attach(environment)
        model.profile.displayName = "Ilya V"
        let anniversary = Date(timeIntervalSince1970: 1_600_000_000)
        var space = try XCTUnwrap(environment.space)
        space.togetherSince = anniversary
        environment.apply(space: space)
        var partner = try XCTUnwrap(environment.partner)
        partner.displayName = "Sofia M"
        environment.apply(member: partner)

        model.reloadFromSession()

        XCTAssertEqual(model.profile.displayName, "Ilya V")
        XCTAssertTrue(model.canSaveName)
        XCTAssertEqual(model.profile.togetherSince, anniversary)
    }

    @MainActor
    func testAnUntouchedNameFollowsTheSession() throws {
        let environment = AppEnvironment.previewSignedIn()
        let model = SettingsViewModel()
        model.attach(environment)
        var member = try XCTUnwrap(environment.currentMember)
        member.displayName = "Ilya from the iPad"
        environment.apply(member: member)

        model.reloadFromSession()

        XCTAssertEqual(model.profile.displayName, "Ilya from the iPad")
        XCTAssertFalse(model.canSaveName)
    }
}
