import XCTest

final class PaywallScreensUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingEndsOnTheTrialOfferAndTheQuietLinkOpensTheComparison() {
        let app = XCUIApplication.corbie(extraArguments: ["-corbie-entitlement", "read_only"])
        app.launch()
        passOnboardingIfShown(app)

        let headline = app.staticTexts[QACatalog.text("paywall.headline")]
        XCTAssertTrue(headline.waitForExistence(timeout: 60), "the trial offer never appeared after onboarding")
        XCTAssertTrue(
            app.staticTexts[QACatalog.text("paywall.trial.sub")].exists,
            "the trial offer does not say the partner pays nothing"
        )
        XCTAssertTrue(
            app.staticTexts[QACatalog.text("paywall.value.question")].exists,
            "the trial offer is missing its value lines"
        )
        let restore = app.buttons[QACatalog.text("paywall.action.restore")]
        XCTAssertTrue(restore.waitForExistence(timeout: 30), "the trial offer has no restore link")
        saveScreenshot(app, named: "paywall_trial_offer")

        let skip = app.buttons[QACatalog.text("paywall.trial.skip")]
        XCTAssertTrue(scrollTo(skip, in: app), "the trial offer has no way to continue without paying")
        skip.tap()

        let free = app.staticTexts
            .matching(NSPredicate(format: "label LIKE[c] %@", QACatalog.text("paywall.compare.free")))
            .firstMatch
        XCTAssertTrue(free.waitForExistence(timeout: 30), "the quiet link did not open the comparison")
        XCTAssertTrue(
            app.staticTexts[QACatalog.text("paywall.compare.premium.capsules")].exists,
            "the comparison table lost its premium rows"
        )
        XCTAssertTrue(
            app.staticTexts[QACatalog.text("paywall.compare.free.recap")].exists,
            "the comparison table lost its free rows"
        )
        saveScreenshot(app, named: "paywall_comparison")

        let close = app.buttons[QACatalog.text("paywall.action.close")].firstMatch
        XCTAssertTrue(close.waitForExistence(timeout: 20), "the comparison has no way out")
        close.tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30), "closing the comparison stranded the app")

        app.terminate()
        app.launchArguments.removeAll { $0 == XCUIApplication.resetStoreArgument }
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 60), "the app did not come back")
        XCTAssertFalse(
            app.staticTexts[QACatalog.text("paywall.trial.sub")].waitForExistence(timeout: 8),
            "the trial offer came back on the next launch"
        )
    }
}
