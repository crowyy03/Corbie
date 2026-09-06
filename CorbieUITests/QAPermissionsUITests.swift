import XCTest

final class QAPermissionsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the permission walk reads English labels")
    }

    func testCalendarImportSaysWhatToDoWhenAccessIsDenied() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.us)
        let settings = app.anyElement(labelContaining: "Couple settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 20), "the Us hub has no settings entry")
        settings.tap()

        let importRow = app.buttons["Import from iPhone Calendar"]
        XCTAssertTrue(scrollTo(importRow, in: app), "settings has no calendar import row")
        importRow.tap()

        XCTAssertTrue(
            app.staticTexts["Corbie has no access to your iPhone calendar."].waitForExistence(timeout: 25),
            "a denied calendar shows no hint"
        )
        XCTAssertTrue(
            app.staticTexts["turn it on in Settings, Privacy, Calendars"].exists,
            "the denied hint does not say where to turn it on"
        )
        saveScreenshot(app, named: "permission_calendar_denied")
        XCTAssertTrue(app.buttons[QAText.cancel].exists, "the import screen cannot be left")
        app.buttons[QAText.cancel].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 15), "cancelling stranded the app")
    }

    func testThePhotoPickerIsReachableWithPhotosDenied() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.wishes)
        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New wish"].waitForExistence(timeout: 20))

        let pick = app.buttons["Choose a photo"]
        XCTAssertTrue(scrollTo(pick, in: app), "the wish editor has no photo control")
        pick.tap()

        let cancel = app.buttons[QAText.cancel]
        XCTAssertTrue(cancel.waitForExistence(timeout: 25), "the photo picker left no way back")
        saveScreenshot(app, named: "permission_photos_denied")
        cancel.tap()
        XCTAssertTrue(
            app.navigationBars["New wish"].waitForExistence(timeout: 20),
            "leaving the photo picker did not return to the editor"
        )
    }

    func testDeniedNotificationsStillOfferAWayBack() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.tasks)
        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New task"].waitForExistence(timeout: 20))
        type(uniqueTitle("Call the vet"), into: app.textFields["What to do"])
        app.switches["Set a date"].tap()
        app.buttons[QAText.save].tap()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deny = springboard.buttons["Don't Allow"]
        if deny.waitForExistence(timeout: 20) {
            saveScreenshot(app, named: "permission_notifications_prompt")
            deny.tap()
        }

        selectTab(app, QATab.us)
        let settings = app.anyElement(labelContaining: "Couple settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 20), "the Us hub has no settings entry")
        settings.tap()

        let notifications = app.buttons["Notifications"]
        XCTAssertTrue(scrollTo(notifications, in: app), "settings has no notifications row")
        notifications.tap()

        XCTAssertTrue(
            app.staticTexts["Turned off in iOS Settings"].waitForExistence(timeout: 25),
            "denied notifications are not reported in settings"
        )
        XCTAssertTrue(
            app.buttons["Open iOS Settings"].exists,
            "denied notifications leave no way to turn them back on"
        )
        saveScreenshot(app, named: "permission_notifications_denied")
    }
}
