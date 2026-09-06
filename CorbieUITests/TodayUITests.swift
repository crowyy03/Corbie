import XCTest

final class TodayUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTodayCarriesTodaysWorkAndOpensAPlanFromTheCarousel() throws {
        let app = UITestFlows.launchFresh()
        UITestFlows.passOnboardingIfShown(app)

        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.buttons["Tasks"].waitForExistence(timeout: 20))

        let taskTitle = uniqueTitle("Water the plants")
        addTaskDueToday(app, tabs: tabs, title: taskTitle)
        let eventTitle = uniqueTitle("Dentist")
        addEventToday(app, tabs: tabs, title: eventTitle)

        tabs.buttons["Today"].tap()

        let taskRow = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", taskTitle)).firstMatch
        if taskRow.waitForExistence(timeout: 20) == false {
            saveScreenshot(app, named: "today_task_missing")
            XCTFail("the task due today never reached the Today tab")
        }
        let checkbox = app.buttons["Tick " + taskTitle]
        XCTAssertTrue(checkbox.waitForExistence(timeout: 10), "the Today block has no checkbox")
        XCTAssertTrue(
            app.anyElement(labelContaining: eventTitle).waitForExistence(timeout: 20),
            "the event starting today is not in the Events block"
        )
        let addPlanCard = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Add a plan")).firstMatch
        if addPlanCard.waitForExistence(timeout: 10) == false {
            saveScreenshot(app, named: "today_add_plan_missing")
            XCTFail("an empty carousel offers no way to add a plan")
        }
        saveScreenshot(app, named: "today_without_a_plan")

        let planTitle = uniqueTitle("Lisbon")
        addPlanCard.tap()
        addPlan(app, title: planTitle)

        let card = try XCTUnwrap(
            hittableButton(app, labelContaining: planTitle),
            "the new plan is not in the carousel"
        )
        saveScreenshot(app, named: "today")

        checkbox.tap()
        XCTAssertTrue(
            checkbox.waitForNonExistence(timeout: 20),
            "a ticked task is still in the Today block"
        )

        card.tap()
        XCTAssertTrue(
            app.navigationBars[planTitle].waitForExistence(timeout: 20),
            "the carousel did not open the plan"
        )
        XCTAssertTrue(tabs.buttons["Plans"].isSelected, "the carousel did not switch to the Plans tab")
    }

    private func addTaskDueToday(_ app: XCUIApplication, tabs: XCUIElement, title: String) {
        tabs.buttons["Tasks"].tap()
        let addFromEmptyState = app.buttons["Add a task"]
        let addFromToolbar = app.buttons["Add"]
        XCTAssertTrue(addFromEmptyState.waitForExistence(timeout: 20) || addFromToolbar.waitForExistence(timeout: 5))
        if addFromEmptyState.exists {
            addFromEmptyState.tap()
        } else {
            addFromToolbar.tap()
        }

        let titleField = app.textFields["Book, buy, pick up"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 15))
        titleField.tap()
        titleField.typeText(title)
        titleField.typeText("\n")

        let dueToggle = app.switches["Set a date"]
        XCTAssertTrue(dueToggle.waitForExistence(timeout: 10))
        UITestFlows.waitUntilHittable(dueToggle)
        if (dueToggle.value as? String) != "1" {
            dueToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        XCTAssertEqual(dueToggle.value as? String, "1")
        app.buttons["Save"].tap()
    }

    private func addEventToday(_ app: XCUIApplication, tabs: XCUIElement, title: String) {
        tabs.buttons["Calendar"].tap()
        app.navigationBars.buttons["Add"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New date"].waitForExistence(timeout: 15))
        type(title, into: app.textFields["Title"])
        app.buttons["Save"].tap()
    }

    private func addPlan(_ app: XCUIApplication, title: String) {
        XCTAssertTrue(app.navigationBars["New plan"].waitForExistence(timeout: 15))
        type(title, into: app.textFields["Title"])
        type("5000", into: app.textFields["Target amount"])
        app.buttons["Save"].tap()
    }

    private func hittableButton(_ app: XCUIApplication, labelContaining text: String) -> XCUIElement? {
        let matches = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text))
        let deadline = Date().addingTimeInterval(20)
        repeat {
            for index in 0 ..< matches.count {
                let element = matches.element(boundBy: index)
                if element.exists, element.isHittable { return element }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < deadline
        return nil
    }
}
