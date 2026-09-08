import CorbieCore
import XCTest
@testable import Corbie

final class ThemePickerTests: XCTestCase {
    func testTheLightAndDarkChoicesCoverEveryTheme() {
        XCTAssertEqual(CorbieTheme.lightChoices, [.ice, .sand, .sage])
        XCTAssertEqual(CorbieTheme.darkChoices, [.deep])
        XCTAssertEqual(Set(CorbieTheme.lightChoices + CorbieTheme.darkChoices), Set(CorbieTheme.allCases))
        for theme in CorbieTheme.lightChoices {
            XCTAssertFalse(theme.isDark)
        }
    }

    func testEveryThemeNameIsInTheCatalog() {
        for theme in CorbieTheme.allCases {
            let name = String(localized: String.LocalizationValue(theme.displayNameKey))
            XCTAssertNotEqual(name, theme.displayNameKey, "theme \(theme.rawValue) has no catalog name")
        }
    }

    func testEveryMemberSlotNameIsInTheCatalog() {
        for slot in MemberColorSlot.allCases {
            let name = String(localized: String.LocalizationValue(slot.displayNameKey))
            XCTAssertNotEqual(name, slot.displayNameKey, "slot \(slot.rawValue) has no catalog name")
        }
    }

    func testTheClashLabelNamesBothTheColourAndThePartner() {
        let label = String(format: String(localized: "member.color.tooclose"), "Teal", "Sofia")
        XCTAssertTrue(label.contains("Teal"))
        XCTAssertTrue(label.contains("Sofia"))
    }

    func testTheShiftMessageNamesBothColours() {
        let message = String(format: String(localized: "settings.you.color.shifted"), "Rose", "Green")
        XCTAssertTrue(message.contains("Rose"))
        XCTAssertTrue(message.contains("Green"))
        XCTAssertFalse(message.contains("!"))
    }

    func testTheProfileDraftCarriesTheSlotBothWays() {
        var draft = ProfileDraft()
        draft.colorSlot = .clay
        XCTAssertEqual(draft.memberDraft.colorKey, MemberColorSlot.clay.rawValue)

        let member = MemberDTO(id: UUID(), colorKey: "p6")
        XCTAssertEqual(ProfileDraft.from(member: member, space: nil, appleName: nil).colorSlot, .green)
    }
}
