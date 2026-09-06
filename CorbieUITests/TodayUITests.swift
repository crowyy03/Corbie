import XCTest

final class TodayUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the Today walk types into fields named in English")
    }

    func testTodayCarriesTodaysWorkAndOpensAPlanFromTheCarousel() throws {
        let app = launchSignedIn()

        let taskTitle = uniqueTitle("Water the plants")
        addTaskDueToday(app, title: taskTitle)
        let eventTitle = uniqueTitle("Dentist")
        addEventToday(app, title: eventTitle)

        selectTab(app, .today)

        let taskRow = app.button(labelContaining: taskTitle)
        if taskRow.waitForExistence(timeout: 30) == false {
            saveScreenshot(app, named: "today_task_missing")
            XCTFail("the task due today never reached the Today tab")
        }
        let checkbox = app.buttons[QACatalog.text("today.row.check", taskTitle)]
        XCTAssertTrue(checkbox.waitForExistence(timeout: 20), "the Today block has no checkbox")
        XCTAssertTrue(
            app.anyElement(labelContaining: eventTitle).waitForExistence(timeout: 30),
            "the event starting today is not in the Events block"
        )

        let addPlanCard = app.button(labelContaining: QACatalog.text("plans.empty.action"))
        XCTAssertTrue(addPlanCard.waitForExistence(timeout: 20), "an empty carousel offers no way to add a plan")
        saveScreenshot(app, named: "today_without_a_plan")

        let planTitle = uniqueTitle("Lisbon")
        addPlanCard.tap()
        addPlan(app, title: planTitle)

        let card = try XCTUnwrap(
            hittableElement(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", planTitle))),
            "the new plan is not in the carousel"
        )
        saveScreenshot(app, named: "today")

        checkbox.tap()
        XCTAssertTrue(checkbox.waitForNonExistence(timeout: 30), "a ticked task is still in the Today block")

        card.tap()
        XCTAssertTrue(
            app.navigationBars[planTitle].waitForExistence(timeout: 30),
            "the carousel did not open the plan"
        )
        XCTAssertTrue(
            app.tabBarButtons.element(boundBy: QATab.plans.rawValue).isSelected,
            "the carousel did not switch to the Plans tab"
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
        UITestFlows.waitUntilHittable(dueToggle)
        if (dueToggle.value as? String) != "1" {
            dueToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        XCTAssertEqual(dueToggle.value as? String, "1")
        app.buttons[QAText.save].tap()
        denySystemPromptIfShown()
    }

    private func addEventToday(_ app: XCUIApplication, title: String) {
        selectTab(app, .calendar)
        let fromEmptyState = app.buttons[QACatalog.text("calendar.upcoming.add")]
        if fromEmptyState.waitForExistence(timeout: 20), fromEmptyState.isHittable {
            fromEmptyState.tap()
        } else {
            app.navigationAdd.tap()
        }
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("calendar.editor.title.new")].waitForExistence(timeout: 25)
        )
        type(title, into: app.textFields[QACatalog.text("calendar.editor.title")])
        app.buttons[QAText.save].tap()
    }

    private func addPlan(_ app: XCUIApplication, title: String) {
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("plans.editor.title.new")].waitForExistence(timeout: 25)
        )
        type(title, into: app.textFields[QACatalog.text("plans.editor.field.title")])
        type("5000", into: app.textFields[QACatalog.text("plans.editor.field.target")])
        app.buttons[QAText.save].tap()
    }
}
