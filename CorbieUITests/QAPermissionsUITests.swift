import XCTest

final class QAPermissionsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the permission walk reads English labels")
    }

    func testCalendarImportSaysWhatToDoWhenAccessIsDenied() throws {
        let app = launchSignedIn()
        openSharedSettings(app)

        let importRow = settingsRow(app, "settings.space.import")
        XCTAssertTrue(scrollTo(importRow, in: app), "settings has no calendar import row")
        importRow.tap()
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("calendar.import.title")].waitForExistence(timeout: 30),
            "the import screen did not open"
        )
        denySystemPromptIfShown()

        let denied = app.staticTexts[QACatalog.text("calendar.import.denied.title")]
        if denied.waitForExistence(timeout: 30) {
            XCTAssertTrue(
                app.staticTexts[QACatalog.text("calendar.import.denied.note")].exists,
                "the denied hint does not say where to turn access on"
            )
            saveScreenshot(app, named: "permission_calendar_denied")
        } else {
            saveScreenshot(app, named: "permission_calendar_allowed")
        }

        let cancel = app.buttons[QAText.cancel].firstMatch
        XCTAssertTrue(cancel.exists, "the import screen cannot be left")
        cancel.tap()
        XCTAssertTrue(
            app.navigationBars[QAText.settingsTitle].waitForExistence(timeout: 25),
            "cancelling the import stranded the app"
        )
    }

    func testThePhotoPickerLeavesAWayBackWhenPhotosAreDenied() throws {
        let app = launchSignedIn()
        selectTab(app, .wishes)
        app.navigationAdd.tap()
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("wishes.editor.title.new")].waitForExistence(timeout: 25)
        )

        let pick = app.buttons[QACatalog.text("wishes.editor.photo.pick")]
        XCTAssertTrue(scrollTo(pick, in: app), "the wish editor has no photo control")
        pick.tap()
        denySystemPromptIfShown()

        let cancel = app.navigationBars.buttons[QAText.cancel].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 40), "the photo picker left no way back")
        saveScreenshot(app, named: "permission_photos_picker")
        cancel.tap()
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("wishes.editor.title.new")].waitForExistence(timeout: 30),
            "leaving the photo picker did not return to the editor"
        )
    }

    func testDeniedNotificationsAreReportedInSettingsWithAWayBack() throws {
        let app = launchSignedIn()
        selectTab(app, .tasks)

        let fromEmptyState = app.buttons[QACatalog.text("tasks.empty.action")]
        if fromEmptyState.waitForExistence(timeout: 20), fromEmptyState.isHittable {
            fromEmptyState.tap()
        } else {
            app.navigationAdd.tap()
        }
        type(uniqueTitle("Call the vet") + "\n", into: app.textFields[QACatalog.text("tasks.editor.field.what")])
        let dueToggle = app.switches[QACatalog.text("tasks.editor.due.toggle")]
        XCTAssertTrue(dueToggle.waitForExistence(timeout: 20))
        waitUntilHittable(dueToggle)
        if (dueToggle.value as? String) != "1" {
            dueToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        app.buttons[QAText.save].tap()

        if denySystemPromptIfShown(timeout: 25) {
            saveScreenshot(app, named: "permission_notifications_prompt")
        }

        openSharedSettings(app)
        let notifications = settingsRow(app, "settings.section.notifications")
        XCTAssertTrue(scrollTo(notifications, in: app), "settings has no notifications row")
        notifications.tap()
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("settings.notifications.title")].waitForExistence(timeout: 30),
            "the notifications screen did not open"
        )

        let denied = app.staticTexts[QACatalog.text("settings.notifications.permission.denied")]
        if denied.waitForExistence(timeout: 30) {
            XCTAssertTrue(
                settingsRow(app, "settings.notifications.permission.open").exists,
                "denied notifications leave no way to turn them back on"
            )
            saveScreenshot(app, named: "permission_notifications_denied")
        } else {
            saveScreenshot(app, named: "permission_notifications_state")
        }
        XCTAssertTrue(
            app.navigationBars.buttons.element(boundBy: 0).isHittable,
            "the notifications screen has no way back"
        )
    }
}
