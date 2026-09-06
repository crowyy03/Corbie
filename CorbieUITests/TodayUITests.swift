import XCTest

final class TodayUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testATaskDueTodayShowsUpOnTheTodayTab() throws {
        let app = XCUIApplication()
        app.launch()
        UITestFlows.passOnboardingIfShown(app)

        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.buttons["Tasks"].waitForExistence(timeout: 10))
        tabs.buttons["Tasks"].tap()

        let addFromEmptyState = app.buttons["Add a task"]
        let addFromToolbar = app.buttons["Add"]
        XCTAssertTrue(addFromEmptyState.waitForExistence(timeout: 10) || addFromToolbar.waitForExistence(timeout: 2))
        if addFromEmptyState.exists {
            addFromEmptyState.tap()
        } else {
            addFromToolbar.tap()
        }

        let titleField = app.textFields["Book, buy, pick up"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10))
        titleField.tap()
        titleField.typeText("Water the plants")
        titleField.typeText("\n")

        let dueToggle = app.switches["Set a date"]
        XCTAssertTrue(dueToggle.waitForExistence(timeout: 5))
        UITestFlows.waitUntilHittable(dueToggle)
        if (dueToggle.value as? String) != "1" {
            dueToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        XCTAssertEqual(dueToggle.value as? String, "1")

        app.buttons["Save"].tap()

        tabs.buttons["Today"].tap()
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Water the plants'")).firstMatch
        if row.waitForExistence(timeout: 15) == false {
            UITestFlows.saveFailureScreenshot(app, named: "today_row_missing")
            XCTFail("the task due today never reached the Today tab")
        }
        XCTAssertTrue(app.buttons["Tick Water the plants"].waitForExistence(timeout: 5))
    }
}
