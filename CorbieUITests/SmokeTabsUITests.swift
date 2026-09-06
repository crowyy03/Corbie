import XCTest

final class SmokeTabsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(QARun.isEnglish, "the smoke walks read English labels")
    }

    func testCalendarDateCreateShowsInUpcoming() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.calendar)

        let title = uniqueTitle("Dentist")
        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New date"].waitForExistence(timeout: 20))
        type(title, into: app.textFields["Title"])
        app.buttons[QAText.save].tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForExistence(timeout: 25),
            "the new date is not under Upcoming"
        )
        saveScreenshot(app, named: "smoke_calendar")
    }

    func testCapsuleCreateShowsInTheList() throws {
        let app = launchSignedIn()
        openUsHub(app)
        app.navigationAdd.tap()
        app.buttons["New capsule"].tap()

        let title = uniqueTitle("First year")
        XCTAssertTrue(app.navigationBars["New capsule"].waitForExistence(timeout: 20))
        type(title, into: app.textFields["Title"])
        app.buttons[QAText.save].tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForExistence(timeout: 25),
            "the new capsule is not in the list"
        )
        saveScreenshot(app, named: "smoke_capsule")
        closeUsHub(app)
    }

    func testFolderTaskCreateAndTick() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.tasks)

        let newFolder = app.buttons["New folder"]
        XCTAssertTrue(newFolder.waitForExistence(timeout: 20), "the Tasks header has no way to add a folder")
        newFolder.tap()

        XCTAssertTrue(app.navigationBars["New folder"].waitForExistence(timeout: 20))
        app.buttons["Shopping"].tap()
        type("Shopping", into: app.textFields["Title"])
        app.buttons[QAText.save].tap()

        let chip = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Shopping")).firstMatch
        XCTAssertTrue(chip.waitForExistence(timeout: 20), "the new folder has no chip")

        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New task"].waitForExistence(timeout: 20))
        type("Batteries", into: app.textFields["What to do"])
        app.buttons[QAText.save].tap()

        let line = app.buttons["Batteries"].firstMatch
        XCTAssertTrue(line.waitForExistence(timeout: 25), "the folder line is not in the folder")
        XCTAssertEqual(line.value as? String, "not ticked")
        saveScreenshot(app, named: "smoke_folder")
        line.tap()
        XCTAssertTrue(waitForValue("ticked", of: line), "ticking the folder line did nothing")
    }

    func testGoalTakesMoneyAndAPrepStep() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.goals)

        let title = uniqueTitle("Lisbon")
        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New goal"].waitForExistence(timeout: 20))
        type(title, into: app.textFields["Title"])
        type("5000", into: app.textFields["Target amount"])
        app.buttons[QAText.save].tap()

        let card = app.button(labelContaining: title)
        XCTAssertTrue(card.waitForExistence(timeout: 25), "the new goal is not in the list")
        card.tap()

        let addMoney = app.buttons["Add money"].firstMatch
        XCTAssertTrue(addMoney.waitForExistence(timeout: 25), "a goal with no money offers no way to add the first")
        addMoney.tap()
        XCTAssertTrue(app.navigationBars["Add money"].waitForExistence(timeout: 20))
        type("120", into: app.textFields["Amount"])
        app.buttons[QAText.save].tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: "120").waitForExistence(timeout: 25),
            "the money added is not on the goal"
        )

        let step = app.textFields["Add a step"]
        type("Collect the documents", into: step)
        step.typeText("\n")

        let stepRow = app.buttons["Collect the documents"].firstMatch
        XCTAssertTrue(stepRow.waitForExistence(timeout: 25), "the prep step is not in the preparation block")
        saveScreenshot(app, named: "smoke_goal")
        stepRow.tap()
        XCTAssertTrue(waitForValue("ticked", of: stepRow), "ticking the prep step did nothing")
    }

    func testPersonBirthdayReachesTheCalendarAndToday() throws {
        let app = launchSignedIn()
        openUsHub(app)

        let people = app.button(labelContaining: "People")
        XCTAssertTrue(people.waitForExistence(timeout: 25), "the Us hub has no People tile")
        people.tap()

        let name = uniqueTitle("Anna")
        addPerson(app, named: name, birthday: birthdayInAFewDays())
        XCTAssertTrue(
            app.anyElement(labelContaining: name).waitForExistence(timeout: 25),
            "the new person is not in the list"
        )
        saveScreenshot(app, named: "smoke_person")
        closeUsHub(app)

        selectTab(app, QATab.calendar)
        XCTAssertTrue(
            app.anyElement(labelContaining: name).waitForExistence(timeout: 30),
            "the birthday did not reach the calendar"
        )
        saveScreenshot(app, named: "smoke_person_in_calendar")

        selectTab(app, QATab.today)
        XCTAssertTrue(
            app.anyElement(labelContaining: name).waitForExistence(timeout: 30),
            "the birthday did not reach Coming up on Today"
        )
        saveScreenshot(app, named: "smoke_person_on_today")
    }

    func testTaskCreateTakeAndDone() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.tasks)

        let title = uniqueTitle("Book the vet")
        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New task"].waitForExistence(timeout: 20))
        type(title, into: app.textFields["What to do"])
        app.buttons[QAText.save].tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForExistence(timeout: 25),
            "the new task is not in the list"
        )
        saveScreenshot(app, named: "smoke_task")

        let take = app.buttons["Take \(title)"]
        XCTAssertTrue(take.waitForExistence(timeout: 15), "a task nobody took has no Take button")
        take.tap()
        XCTAssertTrue(take.waitForNonExistence(timeout: 20), "the task stayed free after Take")

        app.anyElement(labelContaining: title).swipeRight()
        let done = app.buttons[QAText.done]
        XCTAssertTrue(done.waitForExistence(timeout: 15), "the swipe offers no way to finish a task")
        done.tap()
        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForNonExistence(timeout: 25),
            "a finished task is still on the open list"
        )
    }

    func testVoteCreateAndAnswer() throws {
        let app = launchSignedIn()
        openUsHub(app)
        app.navigationAdd.tap()
        app.buttons["New vote"].tap()

        XCTAssertTrue(app.navigationBars["New vote"].waitForExistence(timeout: 20))
        app.buttons["Where to eat"].tap()
        app.buttons[QAText.save].tap()

        let row = app.anyElement(labelContaining: "Where do we eat")
        XCTAssertTrue(row.waitForExistence(timeout: 25), "the new vote is not in the list")
        row.tap()

        let option = app.anyElement(labelContaining: "Cook at home")
        XCTAssertTrue(option.waitForExistence(timeout: 25), "the vote has no options to pick")
        option.tap()

        let answer = app.buttons["Answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 15), "there is no way to submit an answer")
        answer.tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: "Answer saved").waitForExistence(timeout: 25),
            "the answer was not recorded"
        )
        saveScreenshot(app, named: "smoke_vote")
        closeUsHub(app)
    }

    func testWishCreateByHand() throws {
        let app = launchSignedIn()
        selectTab(app, QATab.wishes)

        let title = uniqueTitle("Wool scarf")
        app.navigationAdd.tap()
        XCTAssertTrue(app.navigationBars["New wish"].waitForExistence(timeout: 20))
        type(title, into: app.textFields["Title"])
        app.buttons[QAText.save].tap()

        XCTAssertTrue(
            app.anyElement(labelContaining: title).waitForExistence(timeout: 25),
            "the new wish is not in the list"
        )
        saveScreenshot(app, named: "smoke_wish")
    }

    private func addPerson(_ app: XCUIApplication, named name: String, birthday: (month: Int, day: Int, monthName: String)) {
        let addFromEmptyState = app.buttons["Add a person"]
        if addFromEmptyState.waitForExistence(timeout: 15) {
            addFromEmptyState.tap()
        } else {
            app.navigationAdd.tap()
        }
        XCTAssertTrue(app.navigationBars["New person"].waitForExistence(timeout: 20))
        type(name, into: app.textFields["Name"])

        let monthPicker = app.buttons["Month, Not set"]
        XCTAssertTrue(monthPicker.waitForExistence(timeout: 20), "the person editor has no month picker")
        monthPicker.tap()
        app.buttons[birthday.monthName].tap()

        let dayPicker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Day, ")).firstMatch
        XCTAssertTrue(dayPicker.waitForExistence(timeout: 20), "picking a month did not reveal the day picker")
        dayPicker.tap()
        app.buttons["\(birthday.day)"].firstMatch.tap()
        app.buttons[QAText.save].tap()
    }

    private func waitForValue(_ expected: String, of element: XCUIElement, timeout: TimeInterval = 20) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.value as? String == expected { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return element.value as? String == expected
    }
}
