import XCTest

final class ChoreUITests: XCTestCase {
    private let expectedCardCount = 15

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTheSplitIsBuiltRatedAndThenWaitsForThePartner() throws {
        let app = launchSignedIn()

        openUsHub(app)
        openUsTile(app, key: "us.hub.chores")

        let start = app.buttons[QACatalog.text("chore.action.start")].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 40), "the Chores tile did not open the split")
        saveScreenshot(app, named: "chores_intro")
        start.tap()

        let header = app.staticTexts[QACatalog.text("chore.builder.header")].firstMatch
        XCTAssertTrue(header.waitForExistence(timeout: 40), "the builder did not open on the catalog")
        saveScreenshot(app, named: "chores_builder")

        let carryOn = app.buttons[QACatalog.text("chore.builder.continue")].firstMatch
        XCTAssertTrue(carryOn.waitForExistence(timeout: 20), "the builder has no way forward")
        XCTAssertTrue(carryOn.isEnabled, "the preselected chores should already clear the minimum")
        carryOn.tap()

        closeUsHub(app)
        selectTab(app, .today)

        let todayCard = app.staticTexts[QACatalog.text("today.chores.rate.title")].firstMatch
        XCTAssertTrue(scrollTo(todayCard, in: app), "Today does not offer the chore list to rate")
        saveScreenshot(app, named: "chores_today_card")

        let openFromToday = app.buttons[QACatalog.text("chore.action.rate")].firstMatch
        XCTAssertTrue(openFromToday.waitForExistence(timeout: 20), "the Today card has no way into the deck")
        openFromToday.tap()

        rateEveryCard(app)

        XCTContext.runActivity(
            named: "the reveal needs the partner to rate on a second device, so one device stops here"
        ) { _ in
            let waiting = app.staticTexts[
                QACatalog.text("chore.waiting.title", QACatalog.text("member.name.partner"))
            ].firstMatch
            XCTAssertTrue(waiting.waitForExistence(timeout: 40), "the deck did not end on the waiting state")
            saveScreenshot(app, named: "chores_waiting")

            let nudge = app.buttons[QACatalog.text("chore.action.nudge")].firstMatch
            XCTAssertFalse(nudge.exists, "a space with nobody to nudge should not offer a nudge")
        }
    }

    private func rateEveryCard(_ app: XCUIApplication) {
        let dontMind = app.buttons[QACatalog.text("chore.verdict.fine")].firstMatch
        XCTAssertTrue(dontMind.waitForExistence(timeout: 40), "the deck has no verdict buttons to tap")
        saveScreenshot(app, named: "chores_deck")
        for card in 1 ... expectedCardCount {
            let progress = app.staticTexts[QACatalog.text("chore.rating.progress", card, expectedCardCount)]
            XCTAssertTrue(
                progress.waitForExistence(timeout: 30),
                "card \(card) of \(expectedCardCount) never came up"
            )
            waitUntilHittable(dontMind)
            dontMind.tap()
        }
    }
}
