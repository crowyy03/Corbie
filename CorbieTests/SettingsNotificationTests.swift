import CorbieCore
import XCTest
@testable import Corbie

final class SettingsNotificationTests: XCTestCase {
    func testEveryPreferenceHasOneToggle() {
        XCTAssertEqual(SettingsNotificationToggle.allCases.count, 10)
        var prefs = NotificationPrefs.allEnabled
        for toggle in SettingsNotificationToggle.allCases {
            XCTAssertTrue(toggle.isOn(in: prefs), toggle.rawValue)
            prefs = toggle.set(false, in: prefs)
        }
        XCTAssertEqual(prefs, NotificationPrefs(
            taskAssigned: false,
            taskTakenOrHandedBack: false,
            taskDueToday: false,
            eventSoon: false,
            dateRadar: false,
            partnerAddedWish: false,
            planUpdates: false,
            capsuleUpdates: false,
            voteUpdates: false,
            weeklyRecap: false
        ))
    }

    func testATogglePathTouchesOnlyItsOwnPreference() {
        for toggle in SettingsNotificationToggle.allCases {
            let prefs = toggle.set(false, in: .allEnabled)
            let off = SettingsNotificationToggle.allCases.filter { $0.isOn(in: prefs) == false }
            XCTAssertEqual(off, [toggle], toggle.rawValue)
        }
    }

    func testEveryScheduledKindIsCancelledBySomeToggle() {
        let covered = SettingsNotificationToggle.allCases.flatMap(\.scheduledKinds)
        for kind in NotificationKind.allCases {
            XCTAssertTrue(covered.contains(kind), kind.rawValue)
        }
        XCTAssertEqual(covered.count, Set(covered).count)
    }

    func testAToggleCancelsExactlyTheKindsItsPreferenceGates() {
        for toggle in SettingsNotificationToggle.allCases {
            let prefs = toggle.set(false, in: .allEnabled)
            let disabled = NotificationKind.allCases.filter { $0.isEnabled(in: prefs) == false }
            XCTAssertEqual(Set(toggle.scheduledKinds), Set(disabled), toggle.rawValue)
        }
    }

    func testRemoteKindsHaveNoScheduledCounterpart() {
        XCTAssertTrue(SettingsNotificationToggle.taskAssigned.scheduledKinds.isEmpty)
        XCTAssertTrue(SettingsNotificationToggle.taskHandover.scheduledKinds.isEmpty)
        XCTAssertTrue(SettingsNotificationToggle.partnerWish.scheduledKinds.isEmpty)
        XCTAssertTrue(SettingsNotificationToggle.planUpdates.scheduledKinds.isEmpty)
        XCTAssertTrue(SettingsNotificationToggle.voteUpdates.scheduledKinds.isEmpty)
    }

    func testEveryToggleTitleIsInTheCatalog() {
        for toggle in SettingsNotificationToggle.allCases {
            let value = String(localized: String.LocalizationValue(toggle.titleKey))
            XCTAssertNotEqual(value, toggle.titleKey, toggle.titleKey)
        }
    }

    func testEveryNotificationBodyIsInTheCatalog() {
        for key in NotificationStrings.all {
            XCTAssertNotEqual(String(localized: String.LocalizationValue(key)), key, key)
        }
    }
}
