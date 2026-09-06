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
        let ownerChip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "All")).firstMatch
        XCTAssertTrue(ownerChip.waitForExistence(timeout: 25), "the Tasks owner chips are missing")
        assertTall(ownerChip, "the Tasks owner chip")
        assertBigEnough(app.buttons["New folder"], "the new folder chip")

        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New task"].waitForExistence(timeout: 25))
        assertTall(app.buttons["Nobody"], "the Who segment")
        assertTall(app.switches["Set a date"], "the due date toggle")
        assertTall(app.buttons["Folder"].firstMatch, "the folder picker")
        app.buttons[QAText.cancel].tap()

        openSharedSettings(app)
        let dark = app.buttons["Dark"]
        XCTAssertTrue(scrollTo(dark, in: app), "the appearance section has no Dark option")
        assertTall(dark, "the appearance segment")
        let notifications = app.buttons["Notifications"]
        XCTAssertTrue(scrollTo(notifications, in: app), "settings has no notifications row")
        assertTall(notifications, "the notifications row")
    }

    private func assertTall(_ element: XCUIElement, _ name: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 15), "\(name) is missing")
        guard element.exists else { return }
        XCTAssertGreaterThanOrEqual(
            element.frame.height,
            minimum,
            "\(name) is \(element.frame.height) points tall, under the 44 point minimum"
        )
    }

    private func assertBigEnough(_ element: XCUIElement, _ name: String) {
        assertTall(element, name)
        guard element.exists else { return }
        XCTAssertGreaterThanOrEqual(
            element.frame.width,
            minimum,
            "\(name) is \(element.frame.width) points wide, under the 44 point minimum"
        )
    }
}
