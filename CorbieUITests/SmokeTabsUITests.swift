import XCTest

final class SmokeTabsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTaskCreateTakeAndDone() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.tasks)

        let title = uniqueTitle("Book the vet")
        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New task"].waitForExistence(timeout: 15))
        type(title, into: app.textFields["What to do"])
        app.buttons[QAText.save].tap()

        let row = app.anyElement(labelContaining: title)
        XCTAssertTrue(row.waitForExistence(timeout: 20), "the new task is not in the list")
        saveScreenshot(app, named: "tasks_created")

        let take = app.buttons["Take \(title)"]
        XCTAssertTrue(take.waitForExistence(timeout: 10), "a task nobody took has no Take button")
        take.tap()
        XCTAssertTrue(take.waitForNonExistence(timeout: 15), "the task stayed free after Take")
        saveScreenshot(app, named: "tasks_taken")

        app.anyElement(labelContaining: title).swipeRight()
        let done = app.buttons["Done"]
        if done.waitForExistence(timeout: 5) {
            done.tap()
        }
        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForNonExistence(timeout: 20),
            "a finished task is still on the open list"
        )
    }

    func testEventCreateShowsInUpcoming() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.calendar)

        let title = uniqueTitle("Dentist")
        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New date"].waitForExistence(timeout: 15))
        type(title, into: app.textFields["Title"])
        app.buttons[QAText.save].tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForExistence(timeout: 20),
            "the new date is not under Upcoming"
        )
        saveScreenshot(app, named: "calendar_created")
    }

    func testWishManualCreate() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.wishes)

        let title = uniqueTitle("Wool scarf")
        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New wish"].waitForExistence(timeout: 15))
        type(title, into: app.textFields["Title"])
        app.buttons[QAText.save].tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForExistence(timeout: 20),
            "the new wish is not in the list"
        )
        saveScreenshot(app, named: "wishes_created")
    }

    func testPlanCreateAndExpenseInPlanCurrency() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.plans)

        let title = uniqueTitle("Lisbon")
        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New plan"].waitForExistence(timeout: 15))
        type(title, into: app.textFields["Title"])
        type("5000", into: app.textFields["Target amount"])
        app.buttons[QAText.save].tap()

        let card = app.anyElement(labelContaining: title)
        XCTAssertTrue(card.waitForExistence(timeout: 20), "the new plan is not in the list")
        saveScreenshot(app, named: "plans_created")
        card.tap()

        let addExpense = app.buttons["Add expense"]
        XCTAssertTrue(addExpense.waitForExistence(timeout: 20), "a plan without expenses offers no way to add one")
        addExpense.tap()

        XCTAssertTrue(app.navigationBars["Add expense"].waitForExistence(timeout: 15))
        type("120", into: app.textFields["Amount"])
        app.buttons[QAText.save].tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: "120").waitForExistence(timeout: 20),
            "the expense is not on the plan"
        )
        saveScreenshot(app, named: "plans_expense")
    }

    func testCapsuleCreate() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.us)
        app.navigationAdd.tap()
        app.buttons["New capsule"].tap()

        let title = uniqueTitle("First year")
        XCTAssertTrue(app.navigationBars["New capsule"].waitForExistence(timeout: 15))
        type(title, into: app.textFields["Title"])
        app.buttons[QAText.save].tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForExistence(timeout: 20),
            "the new capsule is not in the list"
        )
        saveScreenshot(app, named: "capsules_created")
    }

    func testVoteCreateAndAnswer() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.us)
        app.navigationAdd.tap()
        app.buttons["New vote"].tap()

        XCTAssertTrue(app.navigationBars["New vote"].waitForExistence(timeout: 15))
        app.buttons["Where to eat"].tap()
        app.buttons[QAText.save].tap()

        let row = app.anyElement(labelContaining: "Where do we eat")
        XCTAssertTrue(row.waitForExistence(timeout: 20), "the new vote is not in the list")
        saveScreenshot(app, named: "votes_created")
        row.tap()

        let option = app.anyElement(labelContaining: "Cook at home")
        XCTAssertTrue(option.waitForExistence(timeout: 20), "the vote has no options to pick")
        option.tap()

        let answer = app.buttons["Answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 10), "there is no way to submit an answer")
        answer.tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: "Answer saved").waitForExistence(timeout: 20),
            "the answer was not recorded"
        )
        saveScreenshot(app, named: "votes_answered")
    }

    func testPersonWithBirthdayReachesTheCalendar() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.us)

        let people = app.anyElement(labelContaining: "People")
        XCTAssertTrue(people.waitForExistence(timeout: 20), "the Us hub has no People tile")
        people.tap()

        let name = uniqueTitle("Anna")
        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New person"].waitForExistence(timeout: 15))
        type(name, into: app.textFields["Name"])

        let today = Calendar.current.dateComponents([.month, .day], from: Date())
        let month = DateFormatter().monthSymbols[(today.month ?? 1) - 1]
        let monthPicker = app.buttons["Month, Not set"]
        XCTAssertTrue(monthPicker.waitForExistence(timeout: 15), "the person editor has no month picker")
        monthPicker.tap()
        app.buttons[month].tap()

        let dayPicker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Day, ")).firstMatch
        XCTAssertTrue(dayPicker.waitForExistence(timeout: 15), "picking a month did not reveal the day picker")
        dayPicker.tap()
        app.buttons["\(today.day ?? 1)"].tap()
        app.buttons[QAText.save].tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: name).waitForExistence(timeout: 20),
            "the new person is not in the list"
        )
        saveScreenshot(app, named: "people_created")

        selectTab(app, QATab.calendar)
        XCTAssertTrue(
            app.anyElement(labelContaining: name).waitForExistence(timeout: 25),
            "the birthday did not reach the calendar"
        )
        saveScreenshot(app, named: "people_birthday_in_calendar")
    }
}
