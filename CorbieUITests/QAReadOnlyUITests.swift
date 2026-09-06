import XCTest

final class QAReadOnlyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the read-only walk reads English labels")
    }

    func testExpiredTrialLocksCreationButKeepsTheCalendar() throws {
        let app = launchSignedIn()
        setTrial(app, action: "Expire the trial")

        selectTab(app, QATab.tasks)
        app.navigationAdd.tap()
        XCTAssertTrue(
            app.staticTexts["One subscription. Both of you."].waitForExistence(timeout: 20),
            "the plus button on Tasks did not raise the paywall after the trial ended"
        )
        saveScreenshot(app, named: "readonly_paywall")
        XCTAssertTrue(
            app.staticTexts["Adding things comes with the subscription."].exists,
            "the paywall does not say why it opened"
        )
        app.buttons["Close"].tap()

        selectTab(app, QATab.calendar)
        app.navigationAdd.tap()
        XCTAssertTrue(
            app.navigationBars["New date"].waitForExistence(timeout: 20),
            "the calendar stopped taking new dates in read-only mode"
        )
        saveScreenshot(app, named: "readonly_calendar_open")
        app.buttons[QAText.cancel].tap()

        setTrial(app, action: "Reset the trial")
    }

    private func setTrial(_ app: XCUIApplication, action: String) {
        selectTab(app, QATab.us)
        let row = app.buttons[action]
        if row.exists == false {
            let settings = app.anyElement(labelContaining: "Couple settings")
            XCTAssertTrue(settings.waitForExistence(timeout: 20), "the Us hub has no settings entry")
            settings.tap()

            let developer = app.buttons["Developer"]
            XCTAssertTrue(scrollTo(developer, in: app), "the developer menu is missing from settings")
            developer.tap()
        }

        XCTAssertTrue(row.waitForExistence(timeout: 15), "the developer menu has no row named \(action)")
        row.tap()
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "state:")).firstMatch
                .waitForExistence(timeout: 15),
            "the developer menu did not report the new state"
        )
        saveScreenshot(app, named: "developer_" + action.replacingOccurrences(of: " ", with: "_"))
    }
}
