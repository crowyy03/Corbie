import XCTest

final class PlansUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testPrepStepsCanBeDraggedIntoAnotherOrder() throws {
        let app = launchSignedIn()
        selectTab(app, .plans)

        let title = uniqueTitle("Wedding")
        openEditor(app, title: QACatalog.text("plans.editor.title.new"), emptyStateKey: "plans.empty.action")
        type(title, into: app.textFields[QACatalog.text("plans.editor.field.title")])
        type("4000", into: app.textFields[QACatalog.text("plans.editor.field.target")])
        app.buttons[QAText.save].tap()

        let card = app.button(labelContaining: title)
        XCTAssertTrue(card.waitForExistence(timeout: 30), "the new plan is not in the Big segment")
        card.tap()

        let stepField = app.textFields[QACatalog.text("plans.detail.steps.add.placeholder")]
        type("Documents\n", into: stepField)
        waitUntilHittable(stepField)
        stepField.typeText("The suit\n")

        let documents = app.buttons["Documents"].firstMatch
        let suit = app.buttons["The suit"].firstMatch
        XCTAssertTrue(documents.waitForExistence(timeout: 30))
        XCTAssertTrue(suit.waitForExistence(timeout: 30))
        XCTAssertLessThan(documents.frame.minY, suit.frame.minY, "the steps did not keep the order they were typed")

        suit.press(forDuration: 1, thenDragTo: documents, withVelocity: .slow, thenHoldForDuration: 1)

        let deadline = Date().addingTimeInterval(10)
        while suit.frame.minY > documents.frame.minY, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertLessThan(suit.frame.minY, documents.frame.minY, "the dragged step did not move above the other")
    }
}
