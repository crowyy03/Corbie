import XCTest

final class FreeTimeUITests: XCTestCase {
    private let privacyNoticeSeenKey = "corbie.freetime.privacynotice.seen"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTheCalendarOpensFreeTimeAndAsksAboutSharingFirst() throws {
        let app = UITestFlows.launchFresh(extraArguments: ["-" + privacyNoticeSeenKey, "NO"])
        UITestFlows.passOnboardingIfShown(app)

        let calendarTab = app.tabBars.firstMatch.buttons["Calendar"]
        XCTAssertTrue(calendarTab.waitForExistence(timeout: 15))
        calendarTab.tap()

        let entry = app.buttons["When you two are free"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 15), "the calendar has no free time button")
        UITestFlows.waitUntilHittable(entry)
        entry.tap()

        let privacy = app.staticTexts["Your calendar stays yours"]
        if privacy.waitForExistence(timeout: 15) == false {
            UITestFlows.saveFailureScreenshot(app, named: "freetime_no_privacy_sheet")
            XCTFail("the privacy sheet did not come up on the first entry")
        }
        XCTAssertTrue(app.buttons["Share my busy times"].exists)

        let notNow = app.buttons["Not now"]
        XCTAssertTrue(notNow.exists, "the privacy sheet has no way to decline")
        notNow.tap()

        XCTAssertTrue(app.navigationBars["When you two are free"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Next 7 days"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Evenings"].exists)
        XCTAssertTrue(app.buttons["Weekends"].exists)
    }
}
