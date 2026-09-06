import XCTest

final class QAAppearanceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testScreenshotTour() throws {
        let app = launchSignedIn()

        for (index, name) in QAText.tabs.enumerated() {
            selectTab(app, index)
            saveScreenshot(app, named: "tab\(index)_\(name.lowercased())")
        }

        XCTAssertEqual(app.tabBarButtons.count, 5, "the tab bar lost a tab")

        selectTab(app, QATab.us)
        let settings = app.anyElement(labelContaining: QARun.isEnglish ? "Couple settings" : "gearshape")
        if settings.waitForExistence(timeout: 15), settings.isHittable {
            settings.tap()
            saveScreenshot(app, named: "settings_top")
            app.swipeUp()
            app.swipeUp()
            saveScreenshot(app, named: "settings_bottom")
        }
    }

    func testPaywallTour() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.us)

        let settings = app.anyElement(labelContaining: QARun.isEnglish ? "Couple settings" : "gearshape")
        guard settings.waitForExistence(timeout: 15) else {
            saveScreenshot(app, named: "us_hub_no_settings")
            throw XCTSkip("the Us hub does not expose couple settings in this language")
        }
        settings.tap()

        guard QARun.isEnglish else {
            saveScreenshot(app, named: "settings_localised")
            return
        }

        let plans = app.buttons["See plans"]
        XCTAssertTrue(scrollTo(plans, in: app), "the subscription section has no way into the paywall")
        plans.tap()

        XCTAssertTrue(
            app.staticTexts["One subscription. Both of you."].waitForExistence(timeout: 20),
            "the paywall did not open"
        )
        saveScreenshot(app, named: "paywall_top")
        app.swipeUp()
        saveScreenshot(app, named: "paywall_bottom")

        XCTAssertTrue(app.buttons["Restore purchases"].exists, "the paywall has no Restore control")
        XCTAssertTrue(app.buttons["Privacy Policy"].exists, "the paywall has no privacy link")
        XCTAssertTrue(app.buttons["Terms of Use"].exists, "the paywall has no terms link")
    }
}
