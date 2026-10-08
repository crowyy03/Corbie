import XCTest

final class PaywallScreensUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testNoTrialScreenAfterOnboardingWhileTheFreeWindowIsOpen() {
        let app = XCUIApplication.corbie(
            extraArguments: XCUIApplication.realEntitlement + XCUIApplication.monetizationOn
        )
        app.launch()
        passOnboardingIfShown(app)

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 60), "the tab bar never appeared")
        let freeLine = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Premium is free for 3 more days"))
            .firstMatch
        XCTAssertTrue(freeLine.waitForExistence(timeout: 30), "Today does not say how long Premium stays free")
        XCTAssertFalse(
            app.staticTexts[QACatalog.text("paywall.trial.sub")].waitForExistence(timeout: 8),
            "the trial screen appeared inside the free window"
        )
        XCTAssertFalse(
            app.buttons[QACatalog.text("paywall.banner.readonly.never")].exists,
            "a read-only banner showed inside the free window"
        )
        saveScreenshot(app, named: "free_window_today")
    }

    func testThePaywallShowsOnceWhenTheFreeWindowIsOverAndTheQuietLinkOpensTheComparison() {
        let app = XCUIApplication.corbie(
            extraArguments: XCUIApplication.realEntitlement + XCUIApplication.freeWindowEnded + XCUIApplication.monetizationOn
        )
        app.launch()
        passOnboardingIfShown(app)

        let headline = app.staticTexts[QACatalog.text("paywall.headline")]
        XCTAssertTrue(headline.waitForExistence(timeout: 60), "the paywall never appeared after the free window")
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
            "the paywall came back on the next launch"
        )
    }
}
