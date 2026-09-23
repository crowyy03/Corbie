import XCTest

final class WishDetailUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAWishOpensAndGoesBackByButtonAndByEdgeSwipe() throws {
        let app = launchSignedIn()
        selectTab(app, .wishes)

        let title = uniqueTitle("Wool scarf")
        app.navigationAdd.tap()
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("wishes.editor.title.new")].waitForExistence(timeout: 25)
        )
        type(title, into: app.textFields[QACatalog.text("wishes.editor.name")])
        app.buttons[QAText.save].tap()

        let card = app.button(labelContaining: title)
        XCTAssertTrue(card.waitForExistence(timeout: 30), "the new wish is not in the list")

        openDetail(card, title: title, in: app)
        saveScreenshot(app, named: "wish_detail_without_link")

        let back = app.buttons[QACatalog.text("common.action.back")].firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 10), "the detail has no back button")
        waitUntilHittable(back)
        back.tap()
        assertBackOnTheList(card, in: app, after: "the back button")

        openDetail(card, title: title, in: app)
        let edge = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5))
        edge.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
        assertBackOnTheList(card, in: app, after: "an edge swipe from the left")
    }

    private func openDetail(_ card: XCUIElement, title: String, in app: XCUIApplication) {
        waitUntilHittable(card)
        card.tap()
        let fulfilled = app.buttons[QACatalog.text("wishes.detail.fulfilled")].firstMatch
        XCTAssertTrue(fulfilled.waitForExistence(timeout: 20), "the detail has no Fulfilled button")
        XCTAssertTrue(app.staticTexts[title].firstMatch.exists, "the detail does not show the wish title")
        XCTAssertFalse(
            app.buttons[QACatalog.text("wishes.detail.open")].exists,
            "a wish without a link offers to open the site"
        )
    }

    private func assertBackOnTheList(_ card: XCUIElement, in app: XCUIApplication, after way: String) {
        let fulfilled = app.buttons[QACatalog.text("wishes.detail.fulfilled")].firstMatch
        XCTAssertTrue(fulfilled.waitForNonExistence(timeout: 15), "\(way) did not leave the detail")
        XCTAssertTrue(card.waitForExistence(timeout: 15), "\(way) did not bring the list back")
        waitUntilHittable(card)
        XCTAssertTrue(card.isHittable, "\(way) left the list covered")
    }
}
