import XCTest

final class QAAppearanceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testScreenshotTourOfEveryTab() throws {
        let app = launchSignedIn()

        XCTAssertEqual(app.tabBarButtons.count, QAText.tabs.count, "the tab bar lost a tab")
        for (index, name) in QAText.tabs.enumerated() {
            selectTab(app, index)
            saveScreenshot(app, named: "tab\(index)_\(name.lowercased())")
        }

        selectTab(app, QATab.today)
        openUsHub(app)
        saveScreenshot(app, named: "us_hub")
        closeUsHub(app)
    }

    func testScreenshotTourOfSettings() throws {
        let app = launchSignedIn()
        openSharedSettings(app)
        saveScreenshot(app, named: "settings_top")
        app.swipeUp()
        app.swipeUp()
        saveScreenshot(app, named: "settings_middle")
        app.swipeUp()
        app.swipeUp()
        saveScreenshot(app, named: "settings_bottom")
    }

    func testScreenshotTourOfFreeTime() throws {
        let app = launchSignedIn(extraArguments: ["-corbie.freetime.privacynotice.seen", "NO"])
        selectTab(app, QATab.calendar)

        let entry = app.buttons[QALabels.current.freeTime]
        XCTAssertTrue(entry.waitForExistence(timeout: 25), "the calendar toolbar has no free time button")
        entry.tap()

        let privacy = app.staticTexts[QALabels.current.freeTimePrivacy]
        XCTAssertTrue(privacy.waitForExistence(timeout: 25), "the first visit did not explain the privacy rule")
        saveScreenshot(app, named: "freetime_privacy_sheet")

        let notNow = app.buttons[QALabels.current.notNow]
        XCTAssertTrue(notNow.waitForExistence(timeout: 15), "the privacy sheet cannot be dismissed")
        notNow.tap()

        XCTAssertTrue(
            app.navigationBars[QALabels.current.freeTime].waitForExistence(timeout: 25),
            "the free time screen did not open behind the privacy sheet"
        )
        saveScreenshot(app, named: "freetime_screen")
    }

    func testPaywallTour() throws {
        try XCTSkipUnless(QARun.isEnglish, "the paywall tour reads English labels")
        let app = launchSignedIn()
        openSharedSettings(app)

        let offers = app.buttons[QALabels.current.seePlans]
        XCTAssertTrue(scrollTo(offers, in: app), "the subscription section has no way into the paywall")
        offers.tap()

        XCTAssertTrue(
            app.staticTexts[QAText.paywallHeadline].waitForExistence(timeout: 25),
            "the paywall did not open"
        )
        saveScreenshot(app, named: "paywall_top")
        app.swipeUp()
        saveScreenshot(app, named: "paywall_bottom")

        XCTAssertTrue(app.buttons[QALabels.current.restore].exists, "the paywall has no Restore control")
        XCTAssertTrue(app.buttons[QALabels.current.privacy].exists, "the paywall has no privacy link")
        XCTAssertTrue(app.buttons[QALabels.current.terms].exists, "the paywall has no terms link")
    }
}
