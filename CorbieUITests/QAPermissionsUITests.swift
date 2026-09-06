import XCTest

final class QAPermissionsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the permission walk reads English labels")
    }

    func testCalendarImportSaysWhatToDoWhenAccessIsDenied() throws {
        let app = launchSignedIn()
        openSharedSettings(app)

        let importRow = app.buttons["Import from iPhone Calendar"]
        XCTAssertTrue(scrollTo(importRow, in: app), "settings has no calendar import row")
        importRow.tap()
        denySystemPromptIfShown()

        XCTAssertTrue(
            app.staticTexts["Corbie has no access to your iPhone calendar."].waitForExistence(timeout: 30),
            "a denied calendar shows no hint"
        )
        XCTAssertTrue(
            app.staticTexts["turn it on in Settings, Privacy, Calendars"].exists,
            "the denied hint does not say where to turn it on"
        )
        saveScreenshot(app, named: "permission_calendar_denied")
        XCTAssertTrue(app.buttons[QAText.cancel].exists, "the import screen cannot be left")
        app.buttons[QAText.cancel].tap()
        XCTAssertTrue(
            app.navigationBars[QAText.settingsTitle].waitForExistence(timeout: 20),
            "cancelling the import stranded the app"
        )
    }

    func testThePhotoPickerIsReachableWithPhotosDenied() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.wishes)
        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New wish"].waitForExistence(timeout: 25))

        let pick = app.buttons["Choose a photo"]
        XCTAssertTrue(scrollTo(pick, in: app), "the wish editor has no photo control")
        pick.tap()

        let picker = app.otherElements["PhotosPickerView"]
        let pickerCancel = app.navigationBars.buttons[QAText.cancel].firstMatch
        XCTAssertTrue(
            picker.waitForExistence(timeout: 30) || pickerCancel.waitForExistence(timeout: 10),
            "the photo picker never came up"
        )
        saveScreenshot(app, named: "permission_photos_denied")

        XCTAssertTrue(pickerCancel.waitForExistence(timeout: 20), "the photo picker left no way back")
        pickerCancel.tap()
        XCTAssertTrue(
            app.navigationBars["New wish"].waitForExistence(timeout: 25),
            "leaving the photo picker did not return to the editor"
        )
    }

    func testDeniedNotificationsStillOfferAWayBack() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.tasks)
        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New task"].waitForExistence(timeout: 25))
        type(uniqueTitle("Call the vet"), into: app.textFields["What to do"])

        let due = app.switches["Set a date"]
        UITestFlows.waitUntilHittable(due)
        if (due.value as? String) != "1" {
            due.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        app.buttons[QAText.save].tap()

        if denySystemPromptIfShown(timeout: 25) {
            saveScreenshot(app, named: "permission_notifications_prompt")
        }

        openSharedSettings(app)
        let notifications = app.buttons["Notifications"]
        XCTAssertTrue(scrollTo(notifications, in: app), "settings has no notifications row")
        notifications.tap()

        XCTAssertTrue(
            app.staticTexts["Turned off in iOS Settings"].waitForExistence(timeout: 30),
            "denied notifications are not reported in settings"
        )
        XCTAssertTrue(
            app.buttons["Open iOS Settings"].exists,
            "denied notifications leave no way to turn them back on"
        )
        saveScreenshot(app, named: "permission_notifications_denied")
    }
}
