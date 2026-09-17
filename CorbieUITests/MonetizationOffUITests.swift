import XCTest

final class MonetizationOffUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAFreeLaunchNeverShowsTheTrialOfferOrTheSubscription() throws {
        let app = XCUIApplication.corbie(extraArguments: ["-corbie-entitlement", "read_only"])
        app.launch()
        passOnboardingIfShown(app)

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 60), "onboarding did not land on the tabs")
        XCTAssertFalse(
            app.staticTexts[QACatalog.text("paywall.trial.sub")].waitForExistence(timeout: 8),
            "the trial offer appeared while monetization is off"
        )

        selectTab(app, .tasks)
        app.navigationAdd.tap()
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("tasks.editor.title.new")].waitForExistence(timeout: 25),
            "a read-only entitlement still gated creation while monetization is off"
        )
        XCTAssertFalse(app.staticTexts[QAText.paywallHeadline].exists, "the paywall opened while monetization is off")
        app.navigationBars.buttons[QAText.cancel].firstMatch.tap()

        openSharedSettings(app)
        let plans = settingsRow(app, "settings.subscription.plans")
        let restore = settingsRow(app, "settings.subscription.restore")
        let support = settingsRow(app, "settings.support.title")
        XCTAssertTrue(scrollTo(support, in: app), "settings has no support entry")
        XCTAssertFalse(plans.exists, "settings offered plans while monetization is off")
        XCTAssertFalse(restore.exists, "settings offered restore while monetization is off")
        saveScreenshot(app, named: "monetization_off_settings")
    }
}
