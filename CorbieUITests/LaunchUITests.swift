import XCTest

final class LaunchUITests: XCTestCase {
    private let screenshotDirectory = ProcessInfo.processInfo.environment["CORBIE_SCREENSHOT_DIR"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSignInReachesFiveTabs() throws {
        let app = XCUIApplication()
        app.launch()

        passOnboardingIfShown(app)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 15))
        XCTAssertEqual(tabBar.buttons.count, 5)

        for (index, name) in ["Tasks", "Calendar", "Wishes", "Plans", "Us"].enumerated() {
            let button = tabBar.buttons[name]
            XCTAssertTrue(button.waitForExistence(timeout: 5), name)
            button.tap()
            save(screenshot: app, named: "tab\(index)_\(name.lowercased())")
        }
    }

    private func passOnboardingIfShown(_ app: XCUIApplication) {
        let debugSignIn = app.buttons["continue without Apple ID (debug build)"]
        guard debugSignIn.waitForExistence(timeout: 8) else { return }
        save(screenshot: app, named: "onboarding_intro")
        debugSignIn.tap()

        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 15))
        save(screenshot: app, named: "onboarding_profile")
        let nameField = app.textFields.firstMatch
        if nameField.exists, (nameField.value as? String)?.isEmpty ?? true {
            nameField.tap()
            nameField.typeText("Ilya")
        }
        continueButton.tap()

        let later = app.buttons["Later"]
        XCTAssertTrue(later.waitForExistence(timeout: 20))
        save(screenshot: app, named: "onboarding_invite")
        later.tap()
    }

    private func save(screenshot app: XCUIApplication, named name: String) {
        let shot = app.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let screenshotDirectory else { return }
        let url = URL(fileURLWithPath: screenshotDirectory).appendingPathComponent(name + ".png")
        try? shot.pngRepresentation.write(to: url)
    }
}
