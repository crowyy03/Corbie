import XCTest

final class SmokeTabsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the smoke walk types into fields named in English")
    }

    func testATaskIsCreatedTakenAndFinished() throws {
        let app = launchSignedIn()
        selectTab(app, .tasks)

        let title = uniqueTitle("Book the vet")
        openEditor(app, title: QACatalog.text("tasks.editor.title.new"), emptyStateKey: "tasks.empty.action")
        type(title, into: app.textFields[QACatalog.text("tasks.editor.field.what")])
        app.buttons[QAText.save].tap()

        let row = app.anyElement(labelContaining: title)
        XCTAssertTrue(row.waitForExistence(timeout: 30), "the new task is not in the list")
        saveScreenshot(app, named: "smoke_task_created")

        let take = app.buttons[QACatalog.text("tasks.action.take.accessibility", title)]
        XCTAssertTrue(take.waitForExistence(timeout: 20), "a task nobody took has no Take button")
        take.tap()
        XCTAssertTrue(take.waitForNonExistence(timeout: 20), "the task stayed free after Take")

        app.anyElement(labelContaining: title).swipeRight()
        let done = app.buttons[QACatalog.text("tasks.action.done")]
        if done.waitForExistence(timeout: 8) {
            done.tap()
        }
        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForNonExistence(timeout: 30),
            "a finished task is still on the open list"
        )
    }

    func testAnEventIsCreatedAndListedUnderUpcoming() throws {
        let app = launchSignedIn()
        selectTab(app, .calendar)

        let title = uniqueTitle("Dentist")
        addEvent(app, title: title)

        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForExistence(timeout: 30),
            "the new date is not under Upcoming"
        )
        saveScreenshot(app, named: "smoke_event_created")
    }

    func testAWishIsCreatedByHand() throws {
        let app = launchSignedIn()
        selectTab(app, .wishes)

        let title = uniqueTitle("Wool scarf")
        app.navigationAdd.tap()
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("wishes.editor.title.new")].waitForExistence(timeout: 25)
        )
        type(title, into: app.textFields[QACatalog.text("wishes.editor.name")])
        app.buttons[QAText.save].tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForExistence(timeout: 30),
            "the new wish is not in the list"
        )
        saveScreenshot(app, named: "smoke_wish_created")
    }

    func testABigPlanTakesMoneyAndAPrepStep() throws {
        let app = launchSignedIn()
        selectTab(app, .plans)

        let title = uniqueTitle("Lisbon")
        openEditor(app, title: QACatalog.text("plans.editor.title.new"), emptyStateKey: "plans.empty.action")
        type(title, into: app.textFields[QACatalog.text("plans.editor.field.title")])
        type("5000", into: app.textFields[QACatalog.text("plans.editor.field.target")])
        app.buttons[QAText.save].tap()

        let card = app.button(labelContaining: title)
        XCTAssertTrue(card.waitForExistence(timeout: 30), "the new plan is not in the Big segment")
        saveScreenshot(app, named: "smoke_plan_created")
        card.tap()

        let addMoney = app.buttons[QACatalog.text("plans.detail.action.addexpense")].firstMatch
        XCTAssertTrue(addMoney.waitForExistence(timeout: 30), "a plan without money offers no way to add the first")
        addMoney.tap()

        XCTAssertTrue(
            app.navigationBars[QACatalog.text("plans.expense.title")].waitForExistence(timeout: 25)
        )
        type("120", into: app.textFields[QACatalog.text("plans.expense.field.amount")])
        app.buttons[QAText.save].tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: "120").waitForExistence(timeout: 30),
            "the money added is not on the plan"
        )

        let stepTitle = "Collect the documents"
        let stepField = app.textFields[QACatalog.text("plans.detail.steps.add.placeholder")]
        XCTAssertTrue(stepField.waitForExistence(timeout: 25), "the preparation block has no add field")
        type(stepTitle + "\n", into: stepField)

        let step = app.buttons[stepTitle].firstMatch
        XCTAssertTrue(step.waitForExistence(timeout: 30), "the new step is not in the preparation block")
        XCTAssertEqual(step.value as? String, QACatalog.text("tasks.item.unchecked"))
        saveScreenshot(app, named: "smoke_plan_money_and_step")
    }

    func testAListTakesAnItemAndTicksIt() throws {
        let app = launchSignedIn()
        selectTab(app, .plans)
        app.buttons[QACatalog.text("plans.segment.lists")].firstMatch.tap()

        let title = uniqueTitle("Groceries")
        openEditor(app, title: QACatalog.text("lists.editor.title.new"), emptyStateKey: "lists.empty.action")
        type(title, into: app.textFields[QACatalog.text("lists.editor.field.title")])
        app.buttons[QAText.save].tap()

        let card = app.button(labelContaining: title)
        XCTAssertTrue(card.waitForExistence(timeout: 30), "the new list is not in the Lists segment")
        card.tap()

        let field = app.textFields[QACatalog.text("lists.detail.additem.placeholder")]
        XCTAssertTrue(field.waitForExistence(timeout: 30), "the list detail has no add field")
        type("Milk\n", into: field)

        let row = app.buttons["Milk"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 30), "the new item is not on the list")
        XCTAssertEqual(row.value as? String, QACatalog.text("lists.item.unchecked"))
        let ticked = expectation(
            for: NSPredicate(format: "value == %@", QACatalog.text("lists.item.checked")),
            evaluatedWith: row
        )
        row.tap()
        wait(for: [ticked], timeout: 30)
        saveScreenshot(app, named: "smoke_list_item_ticked")
    }

    func testACapsuleIsCreatedFromTheUsHub() throws {
        let app = launchSignedIn()
        openUsHub(app)
        app.navigationAdd.tap()
        app.buttons[QACatalog.text("capsules.action.new")].tap()

        let title = uniqueTitle("First year")
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("capsules.action.new")].waitForExistence(timeout: 25)
        )
        type(title, into: app.textFields[QACatalog.text("capsules.editor.title")])
        app.buttons[QAText.save].tap()
        denySystemPromptIfShown()

        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForExistence(timeout: 30),
            "the new capsule is not in the list"
        )
        saveScreenshot(app, named: "smoke_capsule_created")
    }

    func testAVoteIsCreatedAndAnswered() throws {
        let app = launchSignedIn()
        openUsHub(app)
        app.navigationAdd.tap()
        app.buttons[QACatalog.text("votes.action.new")].tap()

        XCTAssertTrue(app.navigationBars[QACatalog.text("votes.action.new")].waitForExistence(timeout: 25))
        app.buttons[QACatalog.text("votes.template.food")].tap()
        app.buttons[QAText.save].tap()

        let question = QACatalog.text("votes.template.food.question")
        let row = app.anyElement(labelContaining: question)
        XCTAssertTrue(row.waitForExistence(timeout: 30), "the new vote is not in the list")
        saveScreenshot(app, named: "smoke_vote_created")
        row.tap()

        let option = app.anyElement(labelContaining: QACatalog.text("votes.template.food.option.home"))
        XCTAssertTrue(option.waitForExistence(timeout: 30), "the vote has no options to pick")
        option.tap()

        let answer = app.buttons[QACatalog.text("votes.detail.answer")]
        XCTAssertTrue(answer.waitForExistence(timeout: 20), "there is no way to submit an answer")
        answer.tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: QACatalog.text("votes.detail.waiting.title"))
                .waitForExistence(timeout: 30),
            "the answer was not recorded"
        )
        saveScreenshot(app, named: "smoke_vote_answered")
    }

    func testAPersonWithABirthdayReachesTheCalendarAndToday() throws {
        let app = launchSignedIn()
        openUsHub(app)
        openUsTile(app, key: "us.hub.people")

        let name = uniqueTitle("Anna")
        let birthday = monthAndDay(daysFromNow: 30)
        openEditor(app, title: QACatalog.text("people.editor.title.new"), emptyStateKey: "people.empty.action")
        type(name, into: app.textFields[QACatalog.text("people.editor.name")])

        let monthPicker = app.buttons[
            QACatalog.text("people.editor.birthday.month") + ", " + QACatalog.text("people.editor.birthday.none")
        ]
        XCTAssertTrue(monthPicker.waitForExistence(timeout: 25), "the person editor has no month picker")
        monthPicker.tap()
        app.buttons[birthday.monthName].tap()

        let dayPicker = app.buttons
            .matching(NSPredicate(format: "label BEGINSWITH %@", QACatalog.text("people.editor.birthday.day") + ", "))
            .firstMatch
        XCTAssertTrue(dayPicker.waitForExistence(timeout: 25), "picking a month did not reveal the day picker")
        dayPicker.tap()
        app.buttons["\(birthday.day)"].tap()
        app.buttons[QAText.save].tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: name).waitForExistence(timeout: 30),
            "the new person is not in the list"
        )
        saveScreenshot(app, named: "smoke_person_created")

        closeUsHub(app)
        selectTab(app, .calendar)
        XCTAssertTrue(
            app.anyElement(labelContaining: name).waitForExistence(timeout: 40),
            "the birthday did not reach the calendar"
        )
        saveScreenshot(app, named: "smoke_person_birthday_in_calendar")

        selectTab(app, .today)
        XCTAssertTrue(
            app.anyElement(labelContaining: name).waitForExistence(timeout: 40),
            "the birthday did not reach the Coming up block on Today"
        )
        saveScreenshot(app, named: "smoke_person_birthday_on_today")
    }

    private func openEditor(_ app: XCUIApplication, title: String, emptyStateKey: String) {
        let fromEmptyState = app.buttons[QACatalog.text(emptyStateKey)]
        if fromEmptyState.waitForExistence(timeout: 15), fromEmptyState.isHittable {
            fromEmptyState.tap()
        } else {
            app.navigationAdd.tap()
        }
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 25), "\(title) did not open")
    }

    private func addEvent(_ app: XCUIApplication, title: String) {
        let fromEmptyState = app.buttons[QACatalog.text("calendar.upcoming.add")]
        if fromEmptyState.waitForExistence(timeout: 15), fromEmptyState.isHittable {
            fromEmptyState.tap()
        } else {
            app.navigationAdd.tap()
        }
        XCTAssertTrue(
            app.navigationBars[QACatalog.text("calendar.editor.title.new")].waitForExistence(timeout: 25)
        )
        type(title, into: app.textFields[QACatalog.text("calendar.editor.title")])
        app.buttons[QAText.save].tap()
    }
}
