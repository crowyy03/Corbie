import XCTest

final class QAUsBadgeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the badge walk types into fields named in English")
    }

    func testABirthdayInsideTheRadarDotsThePillUntilAGiftIsPicked() throws {
        let app = launchSignedIn()
        XCTAssertTrue(
            app.buttons[QAText.usPill].waitForExistence(timeout: 30),
            "a fresh space already carries a dot on the Us pill"
        )

        openUsHub(app)
        openUsTile(app, key: "us.hub.people")
        let name = uniqueTitle("Anna")
        addPerson(app, name: name, birthdayDaysFromNow: 7)
        XCTAssertTrue(app.anyElement(labelContaining: name).waitForExistence(timeout: 30), "the person did not save")
        closeUsHub(app)

        let dotted = app.buttons[QAText.usPillWithDot]
        XCTAssertTrue(
            dotted.waitForExistence(timeout: 30),
            "a birthday seven days out with no gift picked did not dot the Us pill"
        )
        saveScreenshot(app, named: "us_badge_gift_dot")

        dotted.tap()
        openUsTile(app, key: "us.hub.people")
        let row = app.button(labelContaining: name)
        XCTAssertTrue(row.waitForExistence(timeout: 30), "the person is not in the list")
        row.tap()

        let addIdea = app.buttons[QACatalog.text("people.detail.gifts.add")].firstMatch
        XCTAssertTrue(addIdea.waitForExistence(timeout: 30), "the person has no way to add a gift idea")
        addIdea.tap()
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("people.gift.editor.title.new")].waitForExistence(timeout: 25)
        )
        type("Wool scarf", into: app.textFields[QACatalog.text("people.gift.title")])
        app.buttons[QACatalog.text("people.editor.save")].firstMatch.tap()

        let picked = app.buttons[QACatalog.text("people.gift.done")].firstMatch
        XCTAssertTrue(picked.waitForExistence(timeout: 30), "the new idea has no way to mark it picked")
        picked.tap()
        closeUsHub(app)

        XCTAssertTrue(
            app.buttons[QAText.usPill].waitForExistence(timeout: 30),
            "picking a gift did not clear the dot on the Us pill"
        )
        saveScreenshot(app, named: "us_badge_gift_cleared")
    }
}
