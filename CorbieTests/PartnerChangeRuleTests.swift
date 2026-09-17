import CorbieCore
import XCTest
@testable import Corbie

final class PartnerChangeRuleTests: XCTestCase {
    private let partner = MemberDTO(
        id: UUID(),
        displayName: "Sofia",
        colorKey: MemberColorSlot.partnerDefault.rawValue,
        birthdayMonth: 4,
        birthdayDay: 12,
        joinedAt: Date(timeIntervalSince1970: 1_780_000_000),
        sharesBusyTimes: false
    )

    func testAPartnerWhoAppearsOrDisappearsReloadsTheSession() {
        XCTAssertTrue(PartnerChangeRule.needsReload(stored: partner, session: nil))
        XCTAssertTrue(PartnerChangeRule.needsReload(stored: nil, session: partner))
        XCTAssertFalse(PartnerChangeRule.needsReload(stored: nil, session: nil))
    }

    func testAnotherPersonInThePartnerSeatReloadsTheSession() {
        var someoneElse = MemberDTO(id: UUID())
        someoneElse.displayName = partner.displayName
        someoneElse.colorKey = partner.colorKey
        someoneElse.birthdayMonth = partner.birthdayMonth
        someoneElse.birthdayDay = partner.birthdayDay
        someoneElse.joinedAt = partner.joinedAt
        XCTAssertTrue(PartnerChangeRule.needsReload(stored: someoneElse, session: partner))
    }

    func testEveryFieldTheAppShowsReloadsTheSession() {
        let edits: [(inout MemberDTO) -> Void] = [
            { $0.displayName = "Sofi" },
            { $0.colorKey = MemberColorSlot.clay.rawValue },
            { $0.birthdayMonth = 5 },
            { $0.birthdayDay = 13 },
            { $0.joinedAt = Date(timeIntervalSince1970: 1_790_000_000) },
            { $0.sharesBusyTimes = true },
        ]
        for edit in edits {
            var stored = partner
            edit(&stored)
            XCTAssertTrue(PartnerChangeRule.needsReload(stored: stored, session: partner))
        }
    }

    func testThePartnersOwnBookkeepingDoesNotReloadTheSession() {
        var stored = partner
        stored.lastSeenAt = Date()
        stored.lastRecapSeenAt = Date()
        stored.lastUsVisitAt = Date()
        stored.lastQuestionSeenDayKey = "2026-09-17"
        stored.appleUserHash = "hash"
        var prefs = NotificationPrefs.allEnabled
        prefs.weeklyRecap = false
        stored.notificationPrefs = prefs
        XCTAssertFalse(PartnerChangeRule.needsReload(stored: stored, session: partner))
        XCTAssertFalse(PartnerChangeRule.needsReload(stored: partner, session: partner))
    }
}
