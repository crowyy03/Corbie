import XCTest

final class LaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSignInReachesTheFiveTabsAndTheUsPill() throws {
        let app = launchSignedIn()

        let tabBar = app.tabBars.firstMatch
        XCTAssertEqual(tabBar.buttons.count, QATab.allCases.count)

        for tab in QATab.allCases {
            let button = tabBar.buttons.element(boundBy: tab.rawValue)
            XCTAssertTrue(button.waitForExistence(timeout: 10), "the \(tab) tab is missing")
            if QACatalog.has(tab.titleKey, language: QARun.language) {
                XCTAssertEqual(button.label, tab.title, "the \(tab) tab is not named after its catalog key")
            }
            button.tap()
            saveScreenshot(app, named: tab.screenshotName)
        }

        selectTab(app, .today)
        XCTAssertTrue(app.usPill.waitForExistence(timeout: 20), "Today has no Us pill")
    }
}
