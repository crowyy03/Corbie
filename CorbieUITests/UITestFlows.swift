import XCTest

enum UITestFlows {
    static func saveFailureScreenshot(_ app: XCUIApplication, named name: String) {
        guard let directory = ProcessInfo.processInfo.environment["CORBIE_SCREENSHOT_DIR"] else { return }
        let url = URL(fileURLWithPath: directory).appendingPathComponent(name + ".png")
        try? app.screenshot().pngRepresentation.write(to: url)
    }

    static func waitUntilHittable(_ element: XCUIElement, timeout: TimeInterval = 5) {
        let deadline = Date().addingTimeInterval(timeout)
        while element.isHittable == false, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
    }

    static func passOnboardingIfShown(_ app: XCUIApplication) {
        let debugSignIn = app.buttons["continue without Apple ID (debug build)"]
        guard debugSignIn.waitForExistence(timeout: 8) else { return }
        waitUntilHittable(debugSignIn)
        debugSignIn.tap()

        let continueButton = app.buttons["Continue"]
        if continueButton.waitForExistence(timeout: 15) == false {
            saveFailureScreenshot(app, named: "profile_step_missing")
            XCTFail("the profile step never appeared")
        }
        let nameField = app.textFields.firstMatch
        if nameField.exists, (nameField.value as? String)?.isEmpty ?? true {
            nameField.tap()
            nameField.typeText("Ilya")
        }
        continueButton.tap()

        let later = app.buttons["Later"]
        XCTAssertTrue(later.waitForExistence(timeout: 20))
        later.tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
    }
}
