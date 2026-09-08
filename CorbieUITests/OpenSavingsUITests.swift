import XCTest

final class OpenSavingsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAnOpenPlanAddsMoneyUpAndShowsNoProgress() throws {
        let app = launchSignedIn()
        selectTab(app, .plans)

        let title = uniqueTitle("The pot")
        openEditor(app, title: QACatalog.text("plans.editor.title.new"), emptyStateKey: "plans.empty.action")
        let open = app.buttons[QACatalog.text("plans.editor.kind.open")].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 25), "the plan editor has no open savings option")
        open.tap()
        XCTAssertFalse(
            app.textFields[QACatalog.text("plans.editor.field.target")].exists,
            "an open plan still asks for a target amount"
        )
        type(title, into: app.textFields[QACatalog.text("plans.editor.field.title")])
        saveScreenshot(app, named: "open_savings_editor")
        app.buttons[QAText.save].tap()

        let card = app.button(labelContaining: title)
        XCTAssertTrue(card.waitForExistence(timeout: 30), "the open plan is not in the Big segment")
        card.tap()

        addMoney(app, amount: "300", takenOut: false, fromEmptyState: true)
        addMoney(app, amount: "200", takenOut: false, fromEmptyState: false)
        addMoney(app, amount: "120", takenOut: true, fromEmptyState: false)

        XCTAssertTrue(
            app.anyElement(labelContaining: "$380").waitForExistence(timeout: 30),
            "the plan total does not read as the money put in minus the money taken out"
        )
        XCTAssertTrue(
            app.anyElement(labelContaining: QACatalog.text("plans.expense.takenout")).waitForExistence(timeout: 30),
            "the withdrawal is not marked on the contribution"
        )
        assertNoProgress(app, where: "the open plan detail")
        saveScreenshot(app, named: "open_savings_detail")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let saved = app.button(labelContaining: "$380")
        XCTAssertTrue(saved.waitForExistence(timeout: 30), "the card does not carry the total")
        assertNoProgress(app, where: "the open plan card")
        saveScreenshot(app, named: "open_savings_card")

        selectTab(app, .today)
        let carousel = app.button(labelContaining: title)
        XCTAssertTrue(carousel.waitForExistence(timeout: 30), "the open plan is missing from the Today carousel")
        assertNoProgress(app, where: "the Today carousel")
        saveScreenshot(app, named: "open_savings_today")
    }

    private func addMoney(
        _ app: XCUIApplication,
        amount: String,
        takenOut: Bool,
        fromEmptyState: Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if fromEmptyState {
            let cta = app.buttons[QACatalog.text("plans.detail.action.addexpense")].firstMatch
            XCTAssertTrue(cta.waitForExistence(timeout: 30), "a plan without money offers no way to add the first")
            cta.tap()
        } else {
            app.navigationAdd.tap()
        }
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("plans.expense.title")].waitForExistence(timeout: 25),
            "the money sheet did not open",
            file: file,
            line: line
        )
        type(amount, into: app.textFields[QACatalog.text("plans.expense.field.amount")], file: file, line: line)
        if takenOut {
            let toggle = app.switches[QACatalog.text("plans.expense.takenout")].firstMatch
            XCTAssertTrue(
                toggle.waitForExistence(timeout: 25),
                "an open plan has no way to take money out",
                file: file,
                line: line
            )
            flip(toggle)
        }
        app.buttons[QAText.save].tap()
    }

    private func assertNoProgress(
        _ app: XCUIApplication,
        where place: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(
            app.anyElement(labelContaining: "%").exists,
            "\(place) shows a percentage",
            file: file,
            line: line
        )
        XCTAssertFalse(
            app.anyElement(labelContaining: QACatalog.text("plans.card.progress.label")).exists,
            "\(place) still draws the progress bar",
            file: file,
            line: line
        )
    }
}
