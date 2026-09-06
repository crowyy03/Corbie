import XCTest

final class QAOfflineUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the unreachable-server walk reads English labels")
    }

    func testAnUnreachableServerLeavesTheInviteScreenUsable() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.us)
        let settings = app.anyElement(labelContaining: "Couple settings")
        XCTAssertTrue(settings.waitForExistence(timeout: 20), "the Us hub has no settings entry")
        settings.tap()

        let invite = app.buttons["Invite your partner"]
        XCTAssertTrue(scrollTo(invite, in: app), "settings has no invite row")
        invite.tap()

        let failure = app.staticTexts["no code yet - check the connection and try again"]
        let retry = app.buttons["Try again"]
        XCTAssertTrue(failure.waitForExistence(timeout: 40), "a failed invite call reports nothing")
        XCTAssertTrue(retry.exists, "a failed invite call offers no retry")
        saveScreenshot(app, named: "offline_invite_failed")
        XCTAssertTrue(app.buttons["Later"].exists, "the invite screen cannot be left")
        app.buttons["Later"].tap()
    }

    func testAnUnreachableParserStillLetsTheWishBeSavedByHand() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.wishes)
        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New wish"].waitForExistence(timeout: 20))

        type("https://example.com/scarf", into: app.textFields["Link"])
        let hint = app.staticTexts["could not read this link - fill it in by hand"]
        XCTAssertTrue(hint.waitForExistence(timeout: 40), "a failed parse says nothing")
        saveScreenshot(app, named: "offline_parse_failed")

        let title = uniqueTitle("Wool scarf")
        type(title, into: app.textFields["Title"])
        app.buttons[QAText.save].tap()
        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForExistence(timeout: 25),
            "a wish typed by hand after a failed parse did not save"
        )
    }
}
