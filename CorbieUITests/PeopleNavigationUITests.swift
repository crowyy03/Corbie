import XCTest

final class PeopleNavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOpeningAPersonShowsTheirGiftIdeasOnceAndBackReturnsToTheList() throws {
        let app = XCUIApplication()
        app.launch()
        UITestFlows.passOnboardingIfShown(app)

        app.tabBars.buttons["Us"].tap()
        let peopleTile = app.buttons.containing(NSPredicate(format: "label CONTAINS 'People'")).firstMatch
        XCTAssertTrue(peopleTile.waitForExistence(timeout: 10))
        peopleTile.tap()

        let addPerson = app.buttons["Add a person"]
        let addToolbar = app.buttons["Add"]
        XCTAssertTrue(addPerson.waitForExistence(timeout: 10) || addToolbar.waitForExistence(timeout: 2))
        if addPerson.exists {
            addPerson.tap()
        } else {
            addToolbar.tap()
        }

        let nameField = app.textFields["Anna"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        nameField.tap()
        nameField.typeText("Anna")
        app.buttons["Save"].tap()

        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Anna'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        let giftIdeas = app.staticTexts["Gift ideas"]
        XCTAssertTrue(giftIdeas.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Add an idea"].exists)
        XCTAssertFalse(app.buttons["Add a person"].exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertFalse(giftIdeas.exists)
    }
}
