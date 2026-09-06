import XCTest

final class LaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSignInReachesFiveTabsAndTheUsPill() throws {
        let app = launchSignedIn()

        let tabBar = app.tabBars.firstMatch
        XCTAssertEqual(tabBar.buttons.count, 5)

        for (index, name) in QAText.tabs.enumerated() {
            let button = tabBar.buttons.element(boundBy: index)
            XCTAssertTrue(button.waitForExistence(timeout: 10), name)
            button.tap()
            if QARun.isEnglish {
                XCTAssertEqual(button.label, name, "tab \(index) is not \(name)")
            }
            saveScreenshot(app, named: "tab\(index)_\(name.lowercased())")
        }

        selectTab(app, QATab.today)
        openUsHub(app)
        saveScreenshot(app, named: "us_hub")
        closeUsHub(app)
    }
}
