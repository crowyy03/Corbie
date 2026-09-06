import XCTest

final class QASettingsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the settings walk reads English labels")
    }

    func testThemeSwitchAndExport() throws {
        let app = launchSignedIn()
        openSettings(app)

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
        XCTAssertTrue(share.waitForExistence(timeout: 30), "the export produced no file to share")
        share.tap()

        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 30), "sharing the export opened no share sheet")
        saveScreenshot(app, named: "settings_export_share_sheet")
        app.buttons["Close"].firstMatch.tap()
    }

    func testZDeleteAccountReturnsToOnboarding() throws {
        let app = launchSignedIn()
        openSettings(app)

        let delete = app.buttons["Delete account"]
        XCTAssertTrue(scrollTo(delete, in: app), "settings has no way to delete the account")
        delete.tap()

        let confirm = app.buttons["Delete account"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 15), "deleting the account asks for no confirmation")
        saveScreenshot(app, named: "settings_delete_confirm")
        app.sheets.buttons["Delete account"].tap()

        XCTAssertTrue(
            app.buttons[QAText.debugSignIn].waitForExistence(timeout: 60),
            "deleting the account did not land back on onboarding"
        )
        saveScreenshot(app, named: "settings_after_delete")
    }

    private func openSettings(_ app: XCUIApplication) {
        selectTab(app, QATab.us)
        let settings = app.anyElement(labelContaining: "Couple settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 20), "the Us hub has no settings entry")
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 20), "settings did not open")
    }
}
