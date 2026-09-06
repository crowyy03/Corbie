import XCTest

final class QASettingsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the settings walk reads English labels")
    }

    func testBusyTimesSharingTurnsOnAndOffAgain() throws {
        let app = launchSignedIn()
        openSharedSettings(app)

        let toggle = app.switches["Share my busy times"]
        XCTAssertTrue(scrollTo(toggle, in: app), "the privacy section has no busy times toggle")
        XCTAssertEqual(toggle.value as? String, "0", "sharing busy times is on before anyone asked")
        saveScreenshot(app, named: "settings_privacy")

        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        denySystemPromptIfShown()
        XCTAssertTrue(waitForValue("1", of: toggle), "the busy times toggle did not turn on")
        saveScreenshot(app, named: "settings_busytimes_on")

        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertTrue(waitForValue("0", of: toggle), "the busy times toggle did not turn back off")
    }

    func testLeavingTheSpaceIsOnlyOfferedToAPairedMember() throws {
        let app = launchSignedIn()
        openSharedSettings(app)

        let delete = app.buttons["Delete account"]
        XCTAssertTrue(scrollTo(delete, in: app), "settings has no way to delete the account")
        XCTAssertFalse(
            app.buttons["Leave space"].exists,
            "a solo member is offered Leave space, which would leave nothing behind"
        )
        saveScreenshot(app, named: "settings_account")
    }

    func testThemeSwitchAndExport() throws {
        let app = launchSignedIn()
        openSharedSettings(app)

        let dark = app.buttons["Dark"]
        XCTAssertTrue(scrollTo(dark, in: app), "the appearance section has no Dark option")
        dark.tap()
        XCTAssertTrue(dark.isSelected, "picking Dark did not select it")
        saveScreenshot(app, named: "settings_theme_dark")

        let system = app.buttons["System"]
        XCTAssertTrue(system.exists, "the appearance section has no System option")
        system.tap()
        XCTAssertTrue(system.isSelected, "the theme did not go back to System")

        let export = app.buttons["Export my data"]
        XCTAssertTrue(scrollTo(export, in: app), "settings has no export row")
        export.tap()

        let share = app.buttons["Share the file"]
        XCTAssertTrue(share.waitForExistence(timeout: 40), "the export produced no file to share")
        share.tap()

        XCTAssertTrue(
            shareSheet(app).waitForExistence(timeout: 40),
            "sharing the export opened no share sheet"
        )
        saveScreenshot(app, named: "settings_export_share_sheet")
        app.buttons[QAText.close].firstMatch.tap()
        XCTAssertTrue(
            app.navigationBars[QAText.settingsTitle].waitForExistence(timeout: 25),
            "closing the share sheet stranded the app"
        )
    }

    func testZDeleteAccountReturnsToOnboarding() throws {
        let app = launchSignedIn()
        openSharedSettings(app)

        let delete = app.buttons["Delete account"]
        XCTAssertTrue(scrollTo(delete, in: app), "settings has no way to delete the account")
        delete.tap()

        let confirm = app.sheets.buttons["Delete account"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 20), "deleting the account asks for no confirmation")
        saveScreenshot(app, named: "settings_delete_confirm")
        confirm.tap()

        XCTAssertTrue(
            app.buttons[QAText.debugSignIn].waitForExistence(timeout: 90),
            "deleting the account did not land back on onboarding"
        )
        saveScreenshot(app, named: "settings_after_delete")
    }

    private func shareSheet(_ app: XCUIApplication) -> XCUIElement {
        app.otherElements.matching(
            NSPredicate(format: "identifier == %@ OR identifier == %@", "ActivityListView", "UIActivityContentView")
        ).firstMatch
    }

    private func waitForValue(_ expected: String, of element: XCUIElement, timeout: TimeInterval = 25) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.value as? String == expected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return element.value as? String == expected
    }
}
