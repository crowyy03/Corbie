import XCTest

final class QATapTargetUITests: XCTestCase {
    private let minimum: CGFloat = 44
    private let roundingSlack: CGFloat = 0.5

    override func setUpWithError() throws {
        continueAfterFailure = true
        try XCTSkipUnless(QARun.isEnglish, "the tap target walk types into fields named in English")
    }

    func testTheControlsInsideTheScreensAreBigEnough() throws {
        let app = launchSignedIn()

        let title = uniqueTitle("Water the plants")
        addFreeTaskDueToday(app, title: title)

        selectTab(app, .tasks)
        let filter = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", QACatalog.text("tasks.filter.all"))
        ).firstMatch
        XCTAssertTrue(filter.waitForExistence(timeout: 30), "the Tasks filter chips are missing")
        assertBigEnough(filter, "the Tasks filter chip")
        assertBigEnough(
            app.buttons[QACatalog.text("tasks.action.take.accessibility", title)],
            "the Take button on a task row"
        )

        app.navigationAdd.tap()
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("tasks.editor.title.new")].waitForExistence(timeout: 25)
        )
        assertBigEnough(app.buttons[QACatalog.text("tasks.editor.who.nobody")], "the Who segment")
        assertBigEnough(app.switches[QACatalog.text("tasks.editor.due.toggle")], "the due date toggle")
        app.buttons[QAText.cancel].firstMatch.tap()

        selectTab(app, .today)
        assertBigEnough(app.buttons[QACatalog.text("today.row.check", title)], "the Today checkbox")

        openSharedSettings(app)
        let violet = settingsRow(app, "member.color.violet")
        XCTAssertTrue(scrollTo(violet, in: app), "settings has no member colour picker")
        assertBigEnough(violet, "the member colour swatch")

        let deep = settingsRow(app, "theme.name.deep")
        XCTAssertTrue(scrollTo(deep, in: app), "the appearance section has no Deep theme card")
        assertBigEnough(deep, "the theme card")
    }

    private func addFreeTaskDueToday(_ app: XCUIApplication, title: String) {
        selectTab(app, .tasks)
        let fromEmptyState = app.buttons[QACatalog.text("tasks.empty.action")]
        if fromEmptyState.waitForExistence(timeout: 20), fromEmptyState.isHittable {
            fromEmptyState.tap()
        } else {
            app.navigationAdd.tap()
        }
        type(title + "\n", into: app.textFields[QACatalog.text("tasks.editor.field.what")])
        app.buttons[QACatalog.text("tasks.editor.who.nobody")].tap()

        let dueToggle = app.switches[QACatalog.text("tasks.editor.due.toggle")]
        XCTAssertTrue(dueToggle.waitForExistence(timeout: 20))
        waitUntilHittable(dueToggle)
        if (dueToggle.value as? String) != "1" {
            dueToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        }
        app.buttons[QAText.save].tap()
        denySystemPromptIfShown()
    }

    private func assertBigEnough(_ element: XCUIElement, _ name: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 20), "\(name) is missing")
        guard element.exists else { return }
        let frame = element.frame
        XCTAssertGreaterThanOrEqual(
            frame.height,
            minimum - roundingSlack,
            "\(name) is \(frame.height) points tall, under the 44 point minimum"
        )
        XCTAssertGreaterThanOrEqual(
            frame.width,
            minimum - roundingSlack,
            "\(name) is \(frame.width) points wide, under the 44 point minimum"
        )
    }
}
