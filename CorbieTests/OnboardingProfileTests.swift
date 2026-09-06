import CorbieCore
import XCTest
@testable import Corbie

final class OnboardingProfileTests: XCTestCase {
    func testAppleNamePrefersTheGivenName() {
        var components = PersonNameComponents()
        components.givenName = "Sofia"
        components.familyName = "Marino"

        XCTAssertEqual(AppleSignInCredential.displayName(from: components), "Sofia")
    }

    func testAppleNameFallsBackToTheFullNameWithoutAGivenName() {
        var components = PersonNameComponents()
        components.familyName = "Marino"

        XCTAssertEqual(AppleSignInCredential.displayName(from: components), "Marino")
    }

    func testAppleNameIsNilWhenAppleSendsNothingUsable() {
        XCTAssertNil(AppleSignInCredential.displayName(from: nil))
        XCTAssertNil(AppleSignInCredential.displayName(from: PersonNameComponents()))

        var blank = PersonNameComponents()
        blank.givenName = "   "
        XCTAssertNil(AppleSignInCredential.displayName(from: blank))
    }

    func testProfileNeedsANameThatIsNotOnlySpaces() {
        var draft = ProfileDraft()
        XCTAssertFalse(draft.isComplete)

        draft.displayName = "   "
        XCTAssertFalse(draft.isComplete)

        draft.displayName = " Sofia "
        XCTAssertTrue(draft.isComplete)
        XCTAssertEqual(draft.trimmedName, "Sofia")
    }

    func testBirthdayDayIsClampedToTheMonth() {
        var draft = ProfileDraft()
        draft.birthdayMonth = 2
        draft.birthdayDay = 31
        draft.clampBirthdayDay()

        XCTAssertEqual(draft.birthdayDay, 29)
    }

    func testTurningTheBirthdayOffClearsBothParts() {
        var draft = ProfileDraft()
        draft.setBirthday(enabled: true, calendar: .gregorian)
        XCTAssertTrue(draft.hasBirthday)

        draft.setBirthday(enabled: false, calendar: .gregorian)
        XCTAssertFalse(draft.hasBirthday)
        XCTAssertNil(draft.birthdayMonth)
        XCTAssertNil(draft.birthdayDay)
    }

    func testDraftAppliesToTheMemberAndClearsWhatWasRemoved() {
        let member = MemberDTO(
            id: UUID(),
            displayName: "Old",
            colorKey: MemberColorKey.p3.rawValue,
            birthdayMonth: 5,
            birthdayDay: 9
        )
        var draft = ProfileDraft()
        draft.displayName = "Sofia"
        draft.colorKey = .p5

        let updated = draft.applied(to: member)

        XCTAssertEqual(updated.id, member.id)
        XCTAssertEqual(updated.displayName, "Sofia")
        XCTAssertEqual(updated.colorKey, MemberColorKey.p5.rawValue)
        XCTAssertNil(updated.birthdayMonth)
        XCTAssertNil(updated.birthdayDay)
    }

    func testDraftCarriesTogetherSinceOntoTheSpace() {
        let space = SpaceDTO(id: UUID())
        var draft = ProfileDraft()
        draft.togetherSince = Date(timeIntervalSince1970: 1_600_000_000)

        XCTAssertEqual(draft.applied(to: space).togetherSince, draft.togetherSince)
    }

    func testDraftFromStoredMemberWinsOverTheAppleName() {
        let member = MemberDTO(id: UUID(), displayName: "Sofia", colorKey: MemberColorKey.p4.rawValue)
        let space = SpaceDTO(id: UUID(), togetherSince: Date(timeIntervalSince1970: 1))

        let draft = ProfileDraft.from(member: member, space: space, appleName: "Apple Name")

        XCTAssertEqual(draft.displayName, "Sofia")
        XCTAssertEqual(draft.colorKey, .p4)
        XCTAssertEqual(draft.togetherSince, space.togetherSince)
    }

    func testDraftFallsBackToTheAppleNameForANewMember() {
        let draft = ProfileDraft.from(member: nil, space: nil, appleName: "Sofia")

        XCTAssertEqual(draft.displayName, "Sofia")
        XCTAssertEqual(draft.colorKey, .defaultA)
        XCTAssertNil(draft.togetherSince)
    }

    func testMemberDraftLeavesAnEmptyNameUnset() {
        var draft = ProfileDraft()
        draft.displayName = "  "

        XCTAssertNil(draft.memberDraft.displayName)
        XCTAssertEqual(draft.memberDraft.colorKey, MemberColorKey.defaultA.rawValue)
    }

    func testOnboardingStepsAreNumberedAfterTheIntroPages() {
        XCTAssertEqual(OnboardingStepIndex.profile, OnboardingStepIndex.introPageCount)
        XCTAssertEqual(OnboardingStepIndex.invite, OnboardingStepIndex.profile + 1)
    }
}

private extension Calendar {
    static let gregorian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }()
}
