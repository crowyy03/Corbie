import XCTest

final class QAReadOnlyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the developer menu is written in English")
    }

    func testAnExpiredTrialLocksCreationAndKeepsTheCalendarAndToday() throws {
        let app = launchSignedIn()

        let taskTitle = uniqueTitle("Water the plants")
        addTaskDueToday(app, title: taskTitle)

        setTrial(app, action: QAText.expireTrial)
        closeUsHub(app)

        selectTab(app, .tasks)
        app.navigationAdd.tap()
        XCTAssertTrue(
            app.staticTexts[QAText.paywallHeadline].waitForExistence(timeout: 30),
            "the plus button on Tasks did not raise the paywall after the trial ended"
        )
        XCTAssertTrue(
            app.staticTexts[QACatalog.text("paywall.reason.create")].exists,
            "the paywall does not say why it opened"
        )
        saveScreenshot(app, named: "readonly_paywall")
        app.buttons[QACatalog.text("paywall.action.close")].firstMatch.tap()

        selectTab(app, .calendar)
        app.navigationAdd.tap()
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("calendar.editor.title.new")].waitForExistence(timeout: 30),
            "the calendar stopped taking new dates in read-only mode"
        )
        saveScreenshot(app, named: "readonly_calendar_open")
        app.buttons[QAText.cancel].firstMatch.tap()

        selectTab(app, .today)
        XCTAssertTrue(
            app.button(labelContaining: taskTitle).waitForExistence(timeout: 30),
            "Today stopped showing the feed in read-only mode"
        )
        saveScreenshot(app, named: "readonly_today")

        let checkbox = app.buttons[QACatalog.text("today.row.check", taskTitle)]
        XCTAssertTrue(checkbox.waitForExistence(timeout: 20), "the Today block lost its checkbox")
        checkbox.tap()
        XCTAssertTrue(
            app.staticTexts[QAText.paywallHeadline].waitForExistence(timeout: 30),
            "ticking a task in read-only mode did not raise the paywall"
        )
        XCTAssertTrue(
            app.staticTexts[QACatalog.text("paywall.reason.edit")].exists,
            "the paywall does not say that editing is what is locked"
        )
        saveScreenshot(app, named: "readonly_today_checkbox_paywall")
        app.buttons[QACatalog.text("paywall.action.close")].firstMatch.tap()
        XCTAssertTrue(
            app.button(labelContaining: taskTitle).waitForExistence(timeout: 20),
            "the task was ticked even though the paywall stopped the edit"
        )

    }

    func testTheWeeklyRecapStaysFreeAfterTheTrial() throws {
        let app = launchSignedIn()
        setTrial(app, action: QAText.expireTrial)
        closeUsHub(app)
        selectTab(app, .today)

        let recap = app.button(labelContaining: QACatalog.text("recap.title"))
        try XCTSkipUnless(
            scrollTo(recap, in: app, maxSwipes: 6),
            "the weekly recap card only shows from Sunday 19:00 to Monday 09:00"
        )
        saveScreenshot(app, named: "readonly_recap_card")
        recap.tap()
        XCTAssertFalse(
            app.staticTexts[QAText.paywallHeadline].waitForExistence(timeout: 8),
            "the weekly recap asked for a subscription, it is part of the free tier"
        )
    }

    private func addTaskDueToday(_ app: XCUIApplication, title: String) {
        selectTab(app, .tasks)
        let fromEmptyState = app.buttons[QACatalog.text("tasks.empty.action")]
        if fromEmptyState.waitForExistence(timeout: 20), fromEmptyState.isHittable {
            fromEmptyState.tap()
        } else {
            app.navigationAdd.tap()
        }
        type(title + "\n", into: app.textFields[QACatalog.text("tasks.editor.field.what")])

        let dueToggle = app.switches[QACatalog.text("tasks.editor.due.toggle")]
        XCTAssertTrue(dueToggle.waitForExistence(timeout: 20))
        waitUntilHittable(dueToggle)
        if (dueToggle.value as? String) != "1" {
            dueToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        app.buttons[QAText.save].tap()
        denySystemPromptIfShown()
    }

    private func setTrial(_ app: XCUIApplication, action: String) {
        let row = app.buttons[action]
        if row.exists == false {
            openDeveloperMenu(app)
        }
        XCTAssertTrue(row.waitForExistence(timeout: 20), "the developer menu has no row named \(action)")
        row.tap()
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "state:")).firstMatch
                .waitForExistence(timeout: 20),
            "the developer menu did not report the new state"
        )
        saveScreenshot(app, named: "developer_" + action.replacingOccurrences(of: " ", with: "_"))
    }
}
