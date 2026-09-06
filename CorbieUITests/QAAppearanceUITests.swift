import XCTest

final class QAAppearanceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testScreenshotTourOfEveryTab() throws {
        let app = launchSignedIn()

        XCTAssertEqual(app.tabBarButtons.count, QATab.allCases.count, "the tab bar lost a tab")
        for tab in QATab.allCases {
            selectTab(app, tab)
            saveScreenshot(app, named: tab.screenshotName)
        }

        selectTab(app, .plans)
        app.buttons[QACatalog.text("plans.segment.lists")].firstMatch.tap()
        saveScreenshot(app, named: "tab4_plans_lists")

        openUsHub(app)
        saveScreenshot(app, named: "us_hub")
        closeUsHub(app)
    }

    func testScreenshotTourOfSettings() throws {
        let app = launchSignedIn()
        openSharedSettings(app)
        saveScreenshot(app, named: "settings_top")
        app.swipeUp()
        saveScreenshot(app, named: "settings_middle")
        app.swipeUp()
        app.swipeUp()
        saveScreenshot(app, named: "settings_bottom")
    }

    func testThePaywallShowsWhatAppReviewLooksFor() throws {
        let app = launchSignedIn()
        openSharedSettings(app)

        let offers = settingsRow(app, "settings.subscription.plans")
        XCTAssertTrue(scrollTo(offers, in: app), "the subscription section has no way into the paywall")
        offers.tap()

        XCTAssertTrue(
            app.staticTexts[QAText.paywallHeadline].waitForExistence(timeout: 30),
            "the paywall did not open"
        )
        saveScreenshot(app, named: "paywall_top")
        app.swipeUp()
        saveScreenshot(app, named: "paywall_bottom")

        XCTAssertTrue(
            app.buttons[QACatalog.text("paywall.action.restore")].exists,
            "the paywall has no Restore control"
        )
        XCTAssertTrue(
            app.buttons[QACatalog.text("paywall.link.privacy")].exists,
            "the paywall has no privacy link"
        )
        XCTAssertTrue(
            app.buttons[QACatalog.text("paywall.link.terms")].exists,
            "the paywall has no terms link"
        )
        XCTAssertTrue(
            showsRenewalTerms(app),
            "the paywall does not spell out that the subscription renews itself"
        )

        let monthly = app.anyElement(labelContaining: QACatalog.text("paywall.offer.monthly"))
        guard monthly.exists else {
            XCTAssertTrue(
                app.staticTexts[QACatalog.text("paywall.state.unavailable")].exists,
                "the paywall shows neither the offers nor a reason for their absence"
            )
            throw XCTSkip("xcodebuild runs without a StoreKit configuration, so no price can load")
        }
        XCTAssertTrue(
            app.anyElement(labelContaining: QACatalog.text("paywall.offer.yearly")).exists,
            "the paywall names a monthly period but no yearly one"
        )
    }

    private func showsRenewalTerms(_ app: XCUIApplication) -> Bool {
        let sentences = ["paywall.legal.generic", "paywall.legal.monthly", "paywall.legal.yearly"]
            .compactMap { key -> String? in
                QACatalog.text(key)
                    .components(separatedBy: "%@")
                    .max(by: { $0.count < $1.count })?
                    .trimmingCharacters(in: .whitespaces)
            }
        let deadline = Date().addingTimeInterval(20)
        repeat {
            for sentence in sentences where app.staticTexts
                .matching(NSPredicate(format: "label CONTAINS %@", sentence)).count > 0 {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        } while Date() < deadline
        return false
    }
}
