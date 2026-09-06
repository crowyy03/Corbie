import CorbieCore
import XCTest
@testable import Corbie

final class PlansPresentationTests: XCTestCase {
    private let usd = Locale(identifier: "en_US")

    private func plan(
        target: Double,
        saved: Double,
        added: Double,
        status: PlanStatus = .active
    ) -> PlanDTO {
        PlanDTO(
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
        let totals = PlanTotals(plan: plan(target: 5000, saved: 2400, added: 1900))
        XCTAssertEqual(totals.saved, 4300)
        XCTAssertEqual(totals.added, 1900)
        XCTAssertEqual(totals.left, 700)
        XCTAssertEqual(totals.progress, 0.86, accuracy: 0.0001)
        XCTAssertFalse(totals.isOverspent)
        XCTAssertEqual(totals.overspend, 0)
        XCTAssertEqual(totals.overspendFraction, 0)
    }

    func testOverspendIsMeasuredAgainstTheTarget() {
        let totals = PlanTotals(plan: plan(target: 5000, saved: 4000, added: 1340))
        XCTAssertTrue(totals.isOverspent)
        XCTAssertEqual(totals.overspend, 340, accuracy: 0.0001)
        XCTAssertEqual(totals.overspendFraction, 0.068, accuracy: 0.0001)
        XCTAssertEqual(totals.left, 0)
        XCTAssertEqual(totals.overspendBadge(locale: usd), "+$340")
    }

    func testLeftNeverGoesBelowZeroAndTargetlessPlanHasNoProgress() {
        let saturated = PlanTotals(plan: plan(target: 1000, saved: 1500, added: 0))
        XCTAssertEqual(saturated.left, 0)
        XCTAssertEqual(saturated.progress, 1)

        let targetless = PlanTotals(plan: plan(target: 0, saved: 300, added: 700))
        XCTAssertEqual(targetless.progress, 0)
        XCTAssertEqual(targetless.overspendFraction, 0)
        XCTAssertTrue(targetless.isOverspent)
    }

    func testSavedOfTargetReadsAsMoneyInThePlanCurrency() {
        let totals = PlanTotals(plan: plan(target: 5000, saved: 2400, added: 0))
        XCTAssertEqual(totals.savedOfTarget(locale: usd), "$2,400 of $5,000")
    }

    func testPlanTypesCarryTheirOwnIconAndKey() {
        let icons = PlanType.allCases.map(\.systemImage)
        XCTAssertEqual(Set(icons).count, PlanType.allCases.count)
        XCTAssertFalse(icons.contains(where: \.isEmpty))
        XCTAssertEqual(PlanType.trip.titleKey, "plans.type.trip")
        XCTAssertEqual(PlanType.other.titleKey, "plans.type.other")
        XCTAssertEqual(PlanStatus.completed.titleKey, "plans.status.completed")
    }

    func testDateRangeFallsBackToASingleDate() {
        let start = Date(timeIntervalSince1970: 1_760_000_000)
        let end = start.addingTimeInterval(14 * 24 * 60 * 60)
        let range = planDateRange(start: start, end: end, locale: usd)
        let single = planDateRange(start: start, end: nil, locale: usd)
        XCTAssertNotNil(range)
        XCTAssertNotNil(single)
        XCTAssertNotEqual(range, single)
        XCTAssertEqual(
            planDateRange(start: nil, end: end, locale: usd),
            planDateRange(start: end, end: nil, locale: usd)
        )
        XCTAssertNil(planDateRange(start: nil, end: nil, locale: usd))
        XCTAssertEqual(planDateRange(start: start, end: start, locale: usd), single)
    }

    private func step(
        title: String,
        isDone: Bool = false,
        dueAt: Date? = nil,
        sortIndex: Int = 0
    ) -> PlanStepDTO {
        PlanStepDTO(
            id: UUID(),
            planId: UUID(),
            title: title,
            isDone: isDone,
            dueAt: dueAt,
            sortIndex: sortIndex
        )
    }

    func testStepBadgeCountsDoneStepsAndDisappearsWithoutSteps() {
        XCTAssertEqual(planStepsBadge(done: 3, total: 7, locale: usd), "3/7 steps")
        XCTAssertEqual(planStepsBadge(done: 0, total: 1, locale: usd), "0/1 steps")
        XCTAssertNil(planStepsBadge(done: 0, total: 0, locale: usd))
    }

    func testAPlanCarriesItsStepCountsIntoTheCard() {
        var plan = plan(target: 5000, saved: 0, added: 0)
        plan.stepCount = 7
        plan.doneStepCount = 3
        XCTAssertEqual(planStepsBadge(done: plan.doneStepCount, total: plan.stepCount, locale: usd), "3/7 steps")
    }

    func testOnlyAnUnfinishedStepPastItsDateReadsAsOverdue() {
        let now = Date(timeIntervalSince1970: 1_760_000_000)
        let calendar = Calendar(identifier: .gregorian)
        let yesterday = now.addingTimeInterval(-24 * 60 * 60)
        let tomorrow = now.addingTimeInterval(24 * 60 * 60)

        let late = planStepDue(
            for: step(title: "Collect the documents", dueAt: yesterday),
            now: now,
            locale: usd,
            calendar: calendar
        )
        let ahead = planStepDue(
            for: step(title: "Pick up the suit", dueAt: tomorrow),
            now: now,
            locale: usd,
            calendar: calendar
        )
        let lateButDone = planStepDue(
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
        XCTAssertNil(planStepDue(for: step(title: "Book the venue"), now: now, locale: usd, calendar: calendar))
    }

    func testReorderingStepsReturnsTheNewOrderOfIds() {
        let steps = [
            step(title: "Documents", sortIndex: 0),
            step(title: "Suit", sortIndex: 1),
            step(title: "Babysitter", sortIndex: 2),
        ]

        XCTAssertEqual(
            planStepOrder(steps, moving: IndexSet(integer: 2), to: 0),
            [steps[2].id, steps[0].id, steps[1].id]
        )
        XCTAssertEqual(
            planStepOrder(steps, moving: IndexSet(integer: 0), to: 3),
            [steps[1].id, steps[2].id, steps[0].id]
        )
        XCTAssertEqual(
            planStepOrder(steps, moving: IndexSet(integer: 1), to: 1),
            steps.map(\.id)
        )
    }

    func testRoutesTheScreenAnswersFor() {
        let identifier = UUID()
        XCTAssertEqual(PlansRoute.destination(for: .plans), .big)
        XCTAssertEqual(PlansRoute.destination(for: .plan(identifier)), .plan(identifier))
        XCTAssertNil(PlansRoute.destination(for: .wishes))
        XCTAssertNil(PlansRoute.destination(for: .capsules))
        XCTAssertNil(PlansRoute.destination(for: nil))
    }

    @MainActor
    func testPlanRouteOpensTheDetailAndIsConsumedOnce() {
        let identifier = UUID()
        let state = AppState()
        let model = PlansViewModel()
        model.segment = .lists

        state.open(.plan(identifier))
        model.consume(route: state.route, in: state)

        XCTAssertEqual(model.segment, .big)
        XCTAssertEqual(model.openPlan, PlanReference(id: identifier))
        XCTAssertNil(state.route)
    }

    @MainActor
    func testPlansRouteSelectsTheBigSegmentWithoutOpeningAPlan() {
        let state = AppState()
        let model = PlansViewModel()
        model.segment = .lists

        state.open(.plans)
        model.consume(route: state.route, in: state)

        XCTAssertEqual(model.segment, .big)
        XCTAssertNil(model.openPlan)
        XCTAssertNil(state.route)
    }

    @MainActor
    func testAnotherTabsRouteIsLeftForItsOwnScreen() {
        let state = AppState()
        let model = PlansViewModel()

        state.open(.wishes)
        model.consume(route: state.route, in: state)

        XCTAssertEqual(state.route, .wishes)
        XCTAssertEqual(model.segment, .big)
        XCTAssertNil(model.openPlan)
    }
}
