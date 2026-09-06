import XCTest

final class UsBadgeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAnUnansweredVoteDotsThePillUntilItIsAnswered() throws {
        let app = UITestFlows.launchFresh()
        UITestFlows.passOnboardingIfShown(app)

        let quiet = app.buttons["Open the Us hub"].firstMatch
        XCTAssertTrue(quiet.waitForExistence(timeout: 15), "the pill already carries a dot, erase the simulator first")
        quiet.tap()

        app.navigationBars.buttons["Add"].firstMatch.tap()
        app.buttons["New vote"].tap()
        XCTAssertTrue(app.navigationBars["New vote"].waitForExistence(timeout: 15))
        app.buttons["Where to eat"].tap()
        app.buttons["Save"].tap()

        let row = app.anyElement(labelContaining: "Where do we eat")
        XCTAssertTrue(row.waitForExistence(timeout: 20), "the new vote is not in the list")
        closeTheHub(app)

        let dotted = app.buttons["Open the Us hub, something new"].firstMatch
        XCTAssertTrue(dotted.waitForExistence(timeout: 20), "the unanswered vote did not reach the pill")
        dotted.tap()
        openTheVotes(app)

        let vote = app.anyElement(labelContaining: "Where do we eat")
        XCTAssertTrue(vote.waitForExistence(timeout: 20))
        vote.tap()
        let option = app.anyElement(labelContaining: "Cook at home")
        XCTAssertTrue(option.waitForExistence(timeout: 20))
        option.tap()
        app.buttons["Answer"].tap()
        XCTAssertTrue(app.anyElement(labelContaining: "Answer saved").waitForExistence(timeout: 20))
        closeTheHub(app)

        XCTAssertTrue(quiet.waitForExistence(timeout: 20), "the dot stayed after the vote was answered")
    }

    private func openTheVotes(_ app: XCUIApplication) {
        let tile = app.buttons
            .containing(NSPredicate(format: "label CONTAINS 'Ask your partner in secret'"))
            .firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 15), "the hub has no Vote tile")
        tile.tap()
    }

    private func closeTheHub(_ app: XCUIApplication) {
        let close = app.buttons["Close"].firstMatch
        for _ in 0..<3 where close.exists == false {
            app.navigationBars.buttons.element(boundBy: 0).tap()
            _ = close.waitForExistence(timeout: 5)
        }
        XCTAssertTrue(close.waitForExistence(timeout: 10), "there is no way back to the hub")
        close.tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
    }
}
