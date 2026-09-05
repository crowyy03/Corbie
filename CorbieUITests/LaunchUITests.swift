import XCTest

final class LaunchUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsFiveTabs() {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        XCTAssertEqual(tabBar.buttons.count, 5)
    }
}
