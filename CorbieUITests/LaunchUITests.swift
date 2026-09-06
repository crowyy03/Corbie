import XCTest

final class LaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSignInReachesFiveTabs() throws {
        let app = launchSignedIn()

        let tabBar = app.tabBars.firstMatch
        XCTAssertEqual(tabBar.buttons.count, 5)

        for (index, name) in QAText.tabs.enumerated() {
            let button = tabBar.buttons.element(boundBy: index)
            XCTAssertTrue(button.waitForExistence(timeout: 5), name)
            button.tap()
            saveScreenshot(app, named: "tab\(index)_\(name.lowercased())")
        }
    }
}
