import XCTest

final class QAReadOnlyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the read-only walk reads English labels")
    }

    func testAnExpiredTrialLocksAddingButKeepsTheCalendarAndToday() throws {
        let app = launchSignedIn()
        let title = uniqueTitle("Water the plants")
        addTaskDueToday(app, title: title)

        setTrial(app, action: "Expire the trial")
        XCTAssertTrue(
            app.buttons["Trial over. The calendar and Today still work."].waitForExistence(timeout: 25),
            "the read-only banner does not say what is left"
        )
        saveScreenshot(app, named: "readonly_banner")

        selectTab(app, QATab.tasks)
        app.navigationAdd.tap()
        XCTAssertTrue(
            app.staticTexts[QAText.paywallHeadline].waitForExistence(timeout: 25),
            "the plus button on Tasks did not raise the paywall after the trial ended"
        )
        XCTAssertTrue(
            app.staticTexts["Adding things comes with the subscription."].exists,
            "the paywall does not say why it opened"
        )
        saveScreenshot(app, named: "readonly_paywall")
        app.buttons[QAText.close].firstMatch.tap()

        selectTab(app, QATab.calendar)
        app.navigationAdd.tap()
        XCTAssertTrue(
            app.navigationBars["New date"].waitForExistence(timeout: 25),
            "the calendar stopped taking new dates in read-only mode"
        )
        saveScreenshot(app, named: "readonly_calendar_open")
        app.buttons[QAText.cancel].tap()

        selectTab(app, QATab.today)
        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForExistence(timeout: 25),
            "Today stopped showing the feed in read-only mode"
        )
        saveScreenshot(app, named: "readonly_today")

        let checkbox = app.buttons["Tick \(title)"]
        XCTAssertTrue(checkbox.waitForExistence(timeout: 20), "the Today row lost its checkbox")
        checkbox.tap()
        XCTAssertTrue(
            app.staticTexts[QAText.paywallHeadline].waitForExistence(timeout: 25),
            "ticking on Today did not raise the paywall after the trial ended"
        )
        XCTAssertTrue(
            app.staticTexts["Changing things comes with the subscription."].exists,
            "the paywall from Today does not say why it opened"
        )
        saveScreenshot(app, named: "readonly_today_paywall")
        app.buttons[QAText.close].firstMatch.tap()

        setTrial(app, action: "Reset the trial")
    }

    private func addTaskDueToday(_ app: XCUIApplication, title: String) {
        selectTab(app, QATab.tasks)
        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New task"].waitForExistence(timeout: 20))
        type(title, into: app.textFields["What to do"])

        let due = app.switches["Set a date"]
        XCTAssertTrue(due.waitForExistence(timeout: 15), "the task editor has no due date toggle")
        UITestFlows.waitUntilHittable(due)
        if (due.value as? String) != "1" {
            due.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        XCTAssertEqual(due.value as? String, "1", "the due date toggle did not turn on")
        app.buttons[QAText.save].tap()
        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForExistence(timeout: 25),
            "the task due today is not in the list"
        )
    }

    private func setTrial(_ app: XCUIApplication, action: String) {
        openDeveloperMenu(app)
        let row = app.buttons[action]
        XCTAssertTrue(row.waitForExistence(timeout: 20), "the developer menu has no row named \(action)")
        row.tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "state:")).firstMatch
                .waitForExistence(timeout: 20),
            "the developer menu did not report the new state"
        )
        saveScreenshot(app, named: "developer_" + action.replacingOccurrences(of: " ", with: "_"))
        closeUsHub(app)
    }
}
