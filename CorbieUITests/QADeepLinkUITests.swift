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
            app.staticTexts["Have a code?"].waitForExistence(timeout: 40),
            "the join link did not open the join sheet"
        )
        let field = app.textFields["Invite code"]
        XCTAssertTrue(field.waitForExistence(timeout: 20), "the join sheet has no code field")
        XCTAssertEqual(field.value as? String, "K7M2QX", "the code from the link was not filled in")
        saveScreenshot(app, named: "join_sheet_from_deeplink")

        app.buttons[QAText.done].tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 25), "closing the join sheet stranded the app")
    }

    func testTheTabDeepLinksLandOnTheirTabAndTheUsLinkOpensTheHub() throws {
        let app = launchSignedIn()

        for (link, tab) in [("corbie://tasks", QATab.tasks), ("corbie://goals", QATab.goals)] {
            guard let url = URL(string: link) else {
                XCTFail("\(link) is not a URL")
                return
            }
            XCUIDevice.shared.system.open(url)
            let button = app.tabBarButtons.element(boundBy: tab)
            XCTAssertTrue(button.waitForExistence(timeout: 30), "\(link) did not reach a tab bar")
            XCTAssertTrue(waitForSelection(of: button), "\(link) did not select its tab")
        }

        guard let us = URL(string: "corbie://us") else {
            XCTFail("corbie://us is not a URL")
            return
        }
        XCUIDevice.shared.system.open(us)
        XCTAssertTrue(
            app.buttons[QAText.close].firstMatch.waitForExistence(timeout: 30),
            "corbie://us did not open the Us hub"
        )
        saveScreenshot(app, named: "deeplink_us_hub")
        closeUsHub(app)
    }

    private func waitForSelection(of element: XCUIElement, timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.isSelected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return element.isSelected
    }
}
