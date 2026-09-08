import XCTest

final class QuestionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the question walk types an English answer")
    }

    func testTodaysQuestionIsAnsweredAndKeptInTheHistory() throws {
        let app = launchSignedIn()
        let answer = "A dog riding the tram"

        let cta = app.buttons[QACatalog.text("question.action.answer")].firstMatch
        XCTAssertTrue(cta.waitForExistence(timeout: 40), "Today has no question card to answer")
        saveScreenshot(app, named: "question_today_card")
        cta.tap()

        XCTAssertTrue(
            app.navigationBars[QACatalog.text("question.title")].waitForExistence(timeout: 30),
            "the question screen did not open"
        )
        type(answer, into: app.textViews[QACatalog.text("question.editor.label")].firstMatch)

        let save = app.buttons[QAText.save].firstMatch
        XCTAssertTrue(scrollTo(save, in: app), "the question screen has no way to save")
        save.tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: answer).waitForExistence(timeout: 30),
            "the answer is not on the question screen after saving"
        )
        let hidden = QACatalog.text("question.hidden", QACatalog.text("member.name.partner"))
        XCTAssertTrue(
            app.anyElement(labelContaining: hidden).waitForExistence(timeout: 20),
            "the other slot does not say it stays hidden"
        )
        saveScreenshot(app, named: "question_answered")

        app.buttons[QAText.done].firstMatch.tap()
        XCTAssertTrue(
            app.buttons[QACatalog.text("question.action.yours")].firstMatch.waitForExistence(timeout: 30),
            "Today still offers to answer a question that is answered"
        )

        openUsHub(app)
        openUsTile(app, key: "us.hub.questions")
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("question.history.title")].waitForExistence(timeout: 30),
            "the Questions tile did not open the history"
        )
        XCTAssertTrue(
            app.anyElement(labelContaining: answer).waitForExistence(timeout: 30),
            "today is missing from the question history"
        )
        saveScreenshot(app, named: "question_history")
    }
}
