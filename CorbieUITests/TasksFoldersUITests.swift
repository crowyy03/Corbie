import XCTest

final class TasksFoldersUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTheTaskEditorControlsClearTheTapTargetMinimum() throws {
        let app = XCUIApplication()
        app.launch()
        UITestFlows.passOnboardingIfShown(app)

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 15))
        tasksTab.tap()
        app.navigationBars.buttons["Add"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New task"].waitForExistence(timeout: 10))

        assertTall(app.buttons["Nobody"], "the Who segment")
        let dueToggle = app.switches["Set a date"]
        assertTall(dueToggle, "the due date toggle")
        dueToggle.tap()
        XCTAssertTrue(app.datePickers.firstMatch.waitForExistence(timeout: 10), "the date picker never appeared")

        dueToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.datePickers.firstMatch)
        waitForExpectations(timeout: 10)
        assertTall(app.buttons["Folder"].firstMatch, "the folder picker")
    }

    func testAShoppingFolderTakesATaskTicksItAndClearsDone() throws {
        let app = XCUIApplication()
        app.launch()
        UITestFlows.passOnboardingIfShown(app)

        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 15))
        tasksTab.tap()

        let newFolder = app.buttons["New folder"]
        XCTAssertTrue(newFolder.waitForExistence(timeout: 10))
        newFolder.tap()

        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 10))
        app.buttons["Shopping"].tap()
        titleField.tap()
        titleField.typeText("Shopping")
        app.buttons["Save"].tap()

        let folderChip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Shopping")).firstMatch
        XCTAssertTrue(folderChip.waitForExistence(timeout: 10))

        app.navigationBars.buttons["Add"].firstMatch.tap()
        let whatField = app.textFields["What to do"]
        XCTAssertTrue(whatField.waitForExistence(timeout: 10))
        whatField.tap()
        whatField.typeText("Milk")
        XCTAssertTrue(app.buttons["Folder"].firstMatch.exists)
        app.buttons["Save"].tap()

        let milk = app.buttons["Milk"]
        XCTAssertTrue(milk.waitForExistence(timeout: 10))
        XCTAssertEqual(milk.value as? String, "not ticked")
        milk.tap()
        XCTAssertTrue(app.buttons["Milk"].waitForValue("ticked", timeout: 10))

        app.navigationBars.buttons["Folder actions"].firstMatch.tap()
        let clearDone = app.buttons["Clear done"]
        XCTAssertTrue(clearDone.waitForExistence(timeout: 10))
        clearDone.tap()

        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.buttons["Milk"])
        waitForExpectations(timeout: 10)
    }

    private func assertTall(_ element: XCUIElement, _ name: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(name) is missing")
        XCTAssertGreaterThanOrEqual(
            element.frame.height,
            44,
            "\(name) is \(element.frame.height) points tall, under the 44 point minimum"
        )
    }
}

private extension XCUIElement {
    func waitForValue(_ expected: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if value as? String == expected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return value as? String == expected
    }
}
