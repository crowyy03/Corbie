import XCTest

final class QATapTargetUITests: XCTestCase {
    private let minimum: CGFloat = 44

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(QARun.isEnglish, "the tap target walk reads English labels")
    }

    func testTheControlsPeopleTapAreBigEnough() throws {
        let app = launchSignedIn()

        selectTab(app, QATab.tasks)
        let filter = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "All")).firstMatch
        XCTAssertTrue(filter.waitForExistence(timeout: 20), "the Tasks filter chips are missing")
        assertTall(filter, "the Tasks filter chip")

        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New task"].waitForExistence(timeout: 20))
        assertTall(app.buttons["Nobody"], "the Who segment")
        assertTall(app.switches["Set a date"], "the due date toggle")
        assertTall(app.buttons[QAText.save], "the Save button")
        app.buttons[QAText.cancel].tap()

        selectTab(app, QATab.us)
        let settings = app.anyElement(labelContaining: "Couple settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 20), "the Us hub has no settings entry")
        settings.tap()
        let dark = app.buttons["Dark"]
        XCTAssertTrue(scrollTo(dark, in: app), "the appearance section has no Dark option")
        assertTall(dark, "the appearance segment")
    }

    private func assertTall(_ element: XCUIElement, _ name: String) {
        XCTAssertTrue(element.exists, "\(name) is missing")
        guard element.exists else { return }
        let frame = element.frame
        XCTAssertGreaterThanOrEqual(
            frame.height,
            minimum,
            "\(name) is \(frame.height) points tall, under the 44 point minimum"
        )
        XCTAssertGreaterThanOrEqual(
            frame.width,
            minimum,
            "\(name) is \(frame.width) points wide, under the 44 point minimum"
        )
    }
}
