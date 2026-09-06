import CorbieCore
import XCTest
@testable import Corbie

final class GoalsPresentationTests: XCTestCase {
    private let usd = Locale(identifier: "en_US")

    private func goal(
        target: Double,
        saved: Double,
        added: Double,
        status: GoalStatus = .active
    ) -> GoalDTO {
        GoalDTO(
            id: UUID(),
            title: "Lisbon in October",
            type: .trip,
            targetAmount: target,
            currency: "USD",
            savedAmount: saved,
            addedAmount: added,
            status: status
        )
    }

    func testAddedMoneyCountsTowardsSavedAndLeft() {
        let totals = GoalTotals(goal: goal(target: 5000, saved: 2400, added: 1900))
        XCTAssertEqual(totals.saved, 4300)
        XCTAssertEqual(totals.added, 1900)
        XCTAssertEqual(totals.left, 700)
        XCTAssertEqual(totals.progress, 0.86, accuracy: 0.0001)
        XCTAssertFalse(totals.isOverspent)
        XCTAssertEqual(totals.overspend, 0)
        XCTAssertEqual(totals.overspendFraction, 0)
    }

    func testOverspendIsMeasuredAgainstTheTarget() {
        let totals = GoalTotals(goal: goal(target: 5000, saved: 4000, added: 1340))
        XCTAssertTrue(totals.isOverspent)
        XCTAssertEqual(totals.overspend, 340, accuracy: 0.0001)
        XCTAssertEqual(totals.overspendFraction, 0.068, accuracy: 0.0001)
        XCTAssertEqual(totals.left, 0)
        XCTAssertEqual(totals.overspendBadge(locale: usd), "+$340")
    }

    func testLeftNeverGoesBelowZeroAndTargetlessGoalHasNoProgress() {
        let saturated = GoalTotals(goal: goal(target: 1000, saved: 1500, added: 0))
        XCTAssertEqual(saturated.left, 0)
        XCTAssertEqual(saturated.progress, 1)

        let targetless = GoalTotals(goal: goal(target: 0, saved: 300, added: 700))
        XCTAssertEqual(targetless.progress, 0)
        XCTAssertEqual(targetless.overspendFraction, 0)
        XCTAssertTrue(targetless.isOverspent)
    }

    func testSavedOfTargetReadsAsMoneyInTheGoalCurrency() {
        let totals = GoalTotals(goal: goal(target: 5000, saved: 2400, added: 0))
        XCTAssertEqual(totals.savedOfTarget(locale: usd), "$2,400 of $5,000")
    }

    func testGoalTypesCarryTheirOwnIconAndKey() {
        let icons = GoalType.allCases.map(\.systemImage)
        XCTAssertEqual(Set(icons).count, GoalType.allCases.count)
        XCTAssertFalse(icons.contains(where: \.isEmpty))
        XCTAssertEqual(GoalType.trip.titleKey, "goals.type.trip")
        XCTAssertEqual(GoalType.other.titleKey, "goals.type.other")
        XCTAssertEqual(GoalStatus.completed.titleKey, "goals.status.completed")
    }

    func testDateRangeFallsBackToASingleDate() {
        let start = Date(timeIntervalSince1970: 1_760_000_000)
        let end = start.addingTimeInterval(14 * 24 * 60 * 60)
        let range = goalDateRange(start: start, end: end, locale: usd)
        let single = goalDateRange(start: start, end: nil, locale: usd)
        XCTAssertNotNil(range)
        XCTAssertNotNil(single)
        XCTAssertNotEqual(range, single)
        XCTAssertEqual(
            goalDateRange(start: nil, end: end, locale: usd),
            goalDateRange(start: end, end: nil, locale: usd)
        )
        XCTAssertNil(goalDateRange(start: nil, end: nil, locale: usd))
        XCTAssertEqual(goalDateRange(start: start, end: start, locale: usd), single)
    }

    private func step(
        title: String,
        isDone: Bool = false,
        dueAt: Date? = nil,
        sortIndex: Int = 0
    ) -> GoalStepDTO {
        GoalStepDTO(
            id: UUID(),
            goalId: UUID(),
            title: title,
            isDone: isDone,
            dueAt: dueAt,
            sortIndex: sortIndex
        )
    }

    func testStepBadgeCountsDoneStepsAndDisappearsWithoutSteps() {
        XCTAssertEqual(goalStepsBadge(done: 3, total: 7, locale: usd), "3/7 steps")
        XCTAssertEqual(goalStepsBadge(done: 0, total: 1, locale: usd), "0/1 steps")
        XCTAssertNil(goalStepsBadge(done: 0, total: 0, locale: usd))
    }

    func testAGoalCarriesItsStepCountsIntoTheCard() {
        var goal = goal(target: 5000, saved: 0, added: 0)
        goal.stepCount = 7
        goal.doneStepCount = 3
        XCTAssertEqual(goalStepsBadge(done: goal.doneStepCount, total: goal.stepCount, locale: usd), "3/7 steps")
    }

    func testOnlyAnUnfinishedStepPastItsDateReadsAsOverdue() {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let yesterday = now.addingTimeInterval(-24 * 60 * 60)
        let tomorrow = now.addingTimeInterval(24 * 60 * 60)

        let late = goalStepDue(
            for: step(title: "Collect the documents", dueAt: yesterday),
            now: now,
            locale: usd,
            calendar: calendar
        )
        let ahead = goalStepDue(
            for: step(title: "Pick up the suit", dueAt: tomorrow),
            now: now,
            locale: usd,
            calendar: calendar
        )
        let lateButDone = goalStepDue(
            for: step(title: "Collect the documents", isDone: true, dueAt: yesterday),
            now: now,
            locale: usd,
            calendar: calendar
        )

        XCTAssertEqual(late?.isOverdue, true)
        XCTAssertEqual(ahead?.isOverdue, false)
        XCTAssertEqual(lateButDone?.isOverdue, false)
        XCTAssertEqual(late?.text.hasPrefix("was due"), true)
        XCTAssertEqual(ahead?.text.hasPrefix("due"), true)
        XCTAssertEqual(lateButDone?.text.hasPrefix("due"), true)
        XCTAssertNil(goalStepDue(for: step(title: "Book the venue"), now: now, locale: usd, calendar: calendar))
    }

    func testReorderingStepsReturnsTheNewOrderOfIds() {
        let steps = [
            step(title: "Documents", sortIndex: 0),
            step(title: "Suit", sortIndex: 1),
            step(title: "Babysitter", sortIndex: 2),
        ]

        XCTAssertEqual(
            goalStepOrder(steps, moving: IndexSet(integer: 2), to: 0),
            [steps[2].id, steps[0].id, steps[1].id]
        )
        XCTAssertEqual(
            goalStepOrder(steps, moving: IndexSet(integer: 0), to: 3),
            [steps[1].id, steps[2].id, steps[0].id]
        )
        XCTAssertEqual(
            goalStepOrder(steps, moving: IndexSet(integer: 1), to: 1),
            steps.map(\.id)
        )
    }

    func testRoutesTheScreenAnswersFor() {
        let identifier = UUID()
        XCTAssertEqual(GoalsRoute.destination(for: .goals), .list)
        XCTAssertEqual(GoalsRoute.destination(for: .goal(identifier)), .goal(identifier))
        XCTAssertNil(GoalsRoute.destination(for: .wishes))
        XCTAssertNil(GoalsRoute.destination(for: .capsules))
        XCTAssertNil(GoalsRoute.destination(for: nil))
    }

    @MainActor
    func testGoalRouteOpensTheDetailAndIsConsumedOnce() {
        let identifier = UUID()
        let state = AppState()
        let model = GoalsViewModel()

        state.open(.goal(identifier))
        model.consume(route: state.route, in: state)

        XCTAssertEqual(model.openGoal, GoalReference(id: identifier))
        XCTAssertNil(state.route)
    }

    @MainActor
    func testGoalsRouteOpensTheListWithoutOpeningAGoal() {
        let identifier = UUID()
        let state = AppState()
        let model = GoalsViewModel()
        model.openGoal = GoalReference(id: identifier)

        state.open(.goals)
        model.consume(route: state.route, in: state)

        XCTAssertNil(model.openGoal)
        XCTAssertNil(state.route)
    }

    @MainActor
    func testAnotherTabsRouteIsLeftForItsOwnScreen() {
        let state = AppState()
        let model = GoalsViewModel()

        state.open(.wishes)
        model.consume(route: state.route, in: state)

        XCTAssertEqual(state.route, .wishes)
        XCTAssertNil(model.openGoal)
    }
}
