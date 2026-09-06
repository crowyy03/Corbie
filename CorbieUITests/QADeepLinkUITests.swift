import XCTest

final class QADeepLinkUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the join sheet walk reads English labels")
    }

    func testJoinDeepLinkOpensTheJoinSheetWithTheCodeFilledIn() throws {
        let app = launchSignedIn()

        guard let url = URL(string: "corbie://join/K7M2QX") else {
            XCTFail("the join link is not a URL")
            return
        }
        XCUIDevice.shared.system.open(url)

        XCTAssertTrue(
            app.staticTexts["Have a code?"].waitForExistence(timeout: 30),
            "the join link did not open the join sheet"
        )
        let field = app.textFields["Invite code"]
        XCTAssertTrue(field.waitForExistence(timeout: 15), "the join sheet has no code field")
        XCTAssertEqual(field.value as? String, "K7M2QX", "the code from the link was not filled in")
        saveScreenshot(app, named: "join_sheet_from_deeplink")

        app.buttons["Done"].tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "closing the join sheet stranded the app")
    }
}
