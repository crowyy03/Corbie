import XCTest

final class QADeepLinkUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAJoinLinkOpensTheJoinSheetWithTheCodeFilledIn() throws {
        let app = launchSignedIn()

        let code = "K7M2QX"
        guard let url = URL(string: "corbie://join/" + code) else {
            XCTFail("the join link is not a URL")
            return
        }
        XCUIDevice.shared.system.open(url)

        XCTAssertTrue(
            app.staticTexts[QACatalog.text("pairing.join.title")].waitForExistence(timeout: 40),
            "the join link did not open the join sheet"
        )
        let field = app.textFields[QACatalog.text("pairing.join.field.label")]
        XCTAssertTrue(field.waitForExistence(timeout: 25), "the join sheet has no code field")
        XCTAssertEqual(field.value as? String, code, "the code from the link was not filled in")
        saveScreenshot(app, named: "join_sheet_from_deeplink")

        app.buttons[QAText.done].firstMatch.tap()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 25),
            "closing the join sheet stranded the app"
        )
    }
}
