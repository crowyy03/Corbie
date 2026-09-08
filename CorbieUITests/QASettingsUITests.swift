import XCTest

final class QASettingsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the settings walk reads English labels")
    }

    func testTheAppearanceTogglePicksAFixedThemeAndGoesBack() throws {
        let app = launchSignedIn(appearance: "system")
        openSharedSettings(app)

        let deep = settingsRow(app, "theme.name.deep")
        XCTAssertTrue(scrollTo(deep, in: app), "the appearance section has no theme cards")
        let follow = settingsSwitch(app, "settings.appearance.followsystem")
        XCTAssertTrue(follow.isHittable, "the appearance toggle is out of reach")
        XCTAssertEqual(follow.value as? String, "1", "a fresh install does not follow the system")
        XCTAssertTrue(appearanceLabel(app, "settings.appearance.light").exists, "the light choice is missing")

        flip(follow)
        let turnedOff = expectation(for: NSPredicate(format: "value == %@", "0"), evaluatedWith: follow)
        wait(for: [turnedOff], timeout: 20)
        XCTAssertTrue(
            appearanceLabel(app, "settings.appearance.light").waitForNonExistence(timeout: 10),
            "a fixed appearance still asks for a light choice"
        )

        XCTAssertTrue(scrollTo(deep, in: app), "a fixed appearance offers no Deep theme")
        deep.tap()
        XCTAssertTrue(deep.isSelected, "picking Deep did not select it")
        saveScreenshot(app, named: "settings_theme_deep")

        XCTAssertTrue(follow.isHittable, "the appearance toggle went out of reach")
        flip(follow)
        let turnedOn = expectation(for: NSPredicate(format: "value == %@", "1"), evaluatedWith: follow)
        wait(for: [turnedOn], timeout: 20)
        XCTAssertTrue(
            appearanceLabel(app, "settings.appearance.light").waitForExistence(timeout: 10),
            "going back to the system brought no light choice"
        )
    }

    func testTheExportProducesAFileTheShareSheetCanTake() throws {
        let app = launchSignedIn()
        openSharedSettings(app)

        let export = settingsRow(app, "settings.data.export")
        XCTAssertTrue(scrollTo(export, in: app), "settings has no export row")
        export.tap()

        let share = settingsRow(app, "settings.data.share")
        XCTAssertTrue(share.waitForExistence(timeout: 40), "the export produced no file to share")
        share.tap()

        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 40), "sharing the export opened no share sheet")
        saveScreenshot(app, named: "settings_export_share_sheet")
        sheet.swipeDown()
    }

    func testTheBusyTimesToggleTurnsSharingOnAndOff() throws {
        let app = launchSignedIn()
        openSharedSettings(app)

        let toggle = settingsSwitch(app, "freetime.sharing.toggle")
        XCTAssertTrue(scrollTo(toggle, in: app), "the privacy section has no busy times toggle")
        XCTAssertEqual(toggle.value as? String, "0", "a fresh member already shares their busy times")
        saveScreenshot(app, named: "settings_busy_times_off")

        flip(toggle)
        denySystemPromptIfShown()
        let turnedOn = expectation(for: NSPredicate(format: "value == %@", "1"), evaluatedWith: toggle)
        wait(for: [turnedOn], timeout: 40)
        saveScreenshot(app, named: "settings_busy_times_on")

        flip(toggle)
        let turnedOff = expectation(for: NSPredicate(format: "value == %@", "0"), evaluatedWith: toggle)
        wait(for: [turnedOff], timeout: 40)
    }

    func testASoloSpaceOffersNoLeaveRowAndDeletesFromTheAccountSection() throws {
        let app = launchSignedIn()
        openSharedSettings(app)

        let delete = settingsRow(app, "settings.account.delete")
        XCTAssertTrue(scrollTo(delete, in: app), "settings has no way to delete the account")
        XCTAssertFalse(
            settingsRow(app, "settings.account.leave").exists,
            "a solo space offers Leave space, which needs a partner to leave to"
        )
    }

    func testZDeletingTheAccountReturnsToOnboarding() throws {
        let app = launchSignedIn()
        openSharedSettings(app)

        let delete = settingsRow(app, "settings.account.delete")
        XCTAssertTrue(scrollTo(delete, in: app), "settings has no way to delete the account")
        delete.tap()

        let confirm = app.sheets.buttons[QACatalog.text("settings.account.delete")]
        XCTAssertTrue(confirm.waitForExistence(timeout: 20), "deleting the account asks for no confirmation")
        saveScreenshot(app, named: "settings_delete_confirm")
        confirm.tap()

        XCTAssertTrue(
            app.buttons[QAText.debugSignIn].waitForExistence(timeout: 90),
            "deleting the account did not land back on onboarding"
        )
        saveScreenshot(app, named: "settings_after_delete")
    }

    private func appearanceLabel(_ app: XCUIApplication, _ key: String) -> XCUIElement {
        app.staticTexts[QACatalog.text(key)].firstMatch
    }
}
