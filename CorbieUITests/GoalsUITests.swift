import XCTest

final class GoalsUITests: XCTestCase {
    private let goalsTab = 4

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAGoalTakesMoneyAndAPrepStepFromItsOwnScreen() throws {
        let app = XCUIApplication()
        app.launch()
        UITestFlows.passOnboardingIfShown(app)

        let tab = app.tabBars.firstMatch.buttons.element(boundBy: goalsTab)
        XCTAssertTrue(tab.waitForExistence(timeout: 20))
        tab.tap()

        let title = "Lisbon \(Int(Date().timeIntervalSince1970) % 100_000)"
        app.navigationBars.buttons["Add"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New goal"].waitForExistence(timeout: 15))
        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 15))
        titleField.tap()
        titleField.typeText(title)
        let targetField = app.textFields["Target amount"]
        targetField.tap()
        targetField.typeText("5000")
        app.buttons["Save"].tap()

        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20), "the new goal is not in the list")
        card.tap()

        let addMoney = app.buttons["Add money"].firstMatch
        XCTAssertTrue(addMoney.waitForExistence(timeout: 20), "a goal without entries offers no way to add the first")
        addMoney.tap()

        XCTAssertTrue(app.navigationBars["Add money"].waitForExistence(timeout: 15))
        let amountField = app.textFields["Amount"]
        XCTAssertTrue(amountField.waitForExistence(timeout: 15))
        amountField.tap()
        amountField.typeText("120")
        app.buttons["Save"].tap()

        XCTAssertTrue(
            app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "120"))
                .firstMatch.waitForExistence(timeout: 20),
            "the money added is not on the goal"
        )

        let stepField = app.textFields["Add a step"]
        XCTAssertTrue(stepField.waitForExistence(timeout: 15), "the preparation block has no add field")
        stepField.tap()
        stepField.typeText("Collect the documents\n")

        let stepRow = app.buttons["Collect the documents"].firstMatch
        XCTAssertTrue(stepRow.waitForExistence(timeout: 20), "the new step is not in the preparation block")
        XCTAssertEqual(stepRow.value as? String, "not ticked")
        let ticked = expectation(for: NSPredicate(format: "value == %@", "ticked"), evaluatedWith: stepRow)
        stepRow.tap()
        wait(for: [ticked], timeout: 20)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let badged = app.buttons
            .matching(NSPredicate(format: "label CONTAINS %@ AND label CONTAINS %@", title, "1/1 steps"))
            .firstMatch
        XCTAssertTrue(badged.waitForExistence(timeout: 20), "the goal card does not count its prep steps")
    }

    func testPrepStepsCanBeDraggedIntoAnotherOrder() throws {
        let app = XCUIApplication()
        app.launch()
        UITestFlows.passOnboardingIfShown(app)

        let tab = app.tabBars.firstMatch.buttons.element(boundBy: goalsTab)
        XCTAssertTrue(tab.waitForExistence(timeout: 20))
        tab.tap()

        let title = "Wedding \(Int(Date().timeIntervalSince1970) % 100_000)"
        app.navigationBars.buttons["Add"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["New goal"].waitForExistence(timeout: 15))
        let titleField = app.textFields["Title"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 15))
        titleField.tap()
        titleField.typeText(title)
        app.buttons["Save"].tap()

        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", title)).firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 20))
        card.tap()

        let stepField = app.textFields["Add a step"]
        XCTAssertTrue(stepField.waitForExistence(timeout: 20))
        stepField.tap()
        stepField.typeText("Documents\n")
        UITestFlows.waitUntilHittable(stepField)
        stepField.typeText("The suit\n")

        let documents = app.buttons["Documents"].firstMatch
        let suit = app.buttons["The suit"].firstMatch
        XCTAssertTrue(documents.waitForExistence(timeout: 20))
        XCTAssertTrue(suit.waitForExistence(timeout: 20))
        XCTAssertLessThan(documents.frame.minY, suit.frame.minY, "the steps did not keep the order they were typed")

        suit.press(forDuration: 1, thenDragTo: documents, withVelocity: .slow, thenHoldForDuration: 1)

        let deadline = Date().addingTimeInterval(10)
        while suit.frame.minY > documents.frame.minY, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertLessThan(suit.frame.minY, documents.frame.minY, "the dragged step did not move above the other")
    }
}
