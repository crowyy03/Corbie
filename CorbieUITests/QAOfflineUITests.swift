import XCTest

final class QAOfflineUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the offline walk types into fields named in English")
    }

    func testAFailedInviteLeavesTheInviteScreenUsable() throws {
        let app = launchSignedIn()
        openSharedSettings(app)

        let invite = settingsRow(app, "settings.partner.invite")
        XCTAssertTrue(scrollTo(invite, in: app), "settings has no invite row")
        invite.tap()

        let retry = app.buttons[QACatalog.text("pairing.invite.retry")]
        XCTAssertTrue(retry.waitForExistence(timeout: 60), "a failed invite call offers no retry")
        let reasons = [
            "pairing.error.icloud.signedout",
            "pairing.error.icloud.busy",
            "pairing.error.share.pending",
            "error.auth.message",
            "error.network.message",
            "pairing.invite.failed.note"
        ]
        XCTAssertTrue(
            reasons.contains { app.staticTexts[QACatalog.text($0)].exists },
            "a failed invite call does not say why"
        )
        saveScreenshot(app, named: "offline_invite_failed")

        let later = app.buttons[QACatalog.text("pairing.invite.later")]
        XCTAssertTrue(later.exists, "the invite screen cannot be left")
        later.tap()
        XCTAssertTrue(
            app.navigationBars[QAText.settingsTitle].waitForExistence(timeout: 25),
            "leaving the invite screen stranded the app"
        )
    }

    func testAnUnreachableParserStillLetsTheWishBeSavedByHand() throws {
        let app = launchSignedIn()
        selectTab(app, .wishes)
        app.navigationAdd.tap()
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("wishes.editor.title.new")].waitForExistence(timeout: 25)
        )

        type("https://example.com/scarf", into: app.textFields[QACatalog.text("wishes.editor.link")])
        let hint = app.staticTexts[QACatalog.text("wishes.editor.link.failed")]
        XCTAssertTrue(hint.waitForExistence(timeout: 60), "a failed parse says nothing")
        saveScreenshot(app, named: "offline_parse_failed")

        let title = uniqueTitle("Wool scarf")
        type(title, into: app.textFields[QACatalog.text("wishes.editor.name")])
        app.buttons[QAText.save].tap()
        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForExistence(timeout: 40),
            "a wish typed by hand after a failed parse did not save"
        )
    }
}
