import CorbieCore
import XCTest
@testable import Corbie

final class PlansPresentationTests: XCTestCase {
    private let usd = Locale(identifier: "en_US")

    private func plan(
        target: Double,
        saved: Double,
        spent: Double,
        status: PlanStatus = .active
    ) -> PlanDTO {
        PlanDTO(
            id: UUID(),
            title: "Lisbon in October",
            type: .trip,
            targetAmount: target,
            currency: "USD",
            savedAmount: saved,
            spentAmount: spent,
            status: status
        )
    }

    func testTotalsSplitSavedSpentAndLeft() {
        let totals = PlanTotals(plan: plan(target: 5000, saved: 2400, spent: 1900))
        XCTAssertEqual(totals.saved, 2400)
        XCTAssertEqual(totals.spent, 1900)
        XCTAssertEqual(totals.left, 2600)
        XCTAssertEqual(totals.progress, 0.48, accuracy: 0.0001)
        XCTAssertFalse(totals.isOverspent)
        XCTAssertEqual(totals.overspend, 0)
        XCTAssertEqual(totals.overspendFraction, 0)
    }

    func testOverspendIsMeasuredAgainstTheTarget() {
        let totals = PlanTotals(plan: plan(target: 5000, saved: 5000, spent: 5340))
        XCTAssertTrue(totals.isOverspent)
        XCTAssertEqual(totals.overspend, 340, accuracy: 0.0001)
        XCTAssertEqual(totals.overspendFraction, 0.068, accuracy: 0.0001)
        XCTAssertEqual(totals.left, 0)
        XCTAssertEqual(totals.overspendBadge(locale: usd), "+$340")
    }

    func testLeftNeverGoesBelowZeroAndTargetlessPlanHasNoProgress() {
        let saturated = PlanTotals(plan: plan(target: 1000, saved: 1500, spent: 0))
        XCTAssertEqual(saturated.left, 0)
        XCTAssertEqual(saturated.progress, 1)

        let targetless = PlanTotals(plan: plan(target: 0, saved: 300, spent: 700))
        XCTAssertEqual(targetless.progress, 0)
        XCTAssertEqual(targetless.overspendFraction, 0)
        XCTAssertTrue(targetless.isOverspent)
    }

    func testSavedOfTargetReadsAsMoneyInThePlanCurrency() {
        let totals = PlanTotals(plan: plan(target: 5000, saved: 2400, spent: 0))
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

    func testListTemplatesCarryTheirOwnIconTitleAndHint() {
        let icons = ListTemplate.allCases.map(\.systemImage)
        XCTAssertEqual(Set(icons).count, ListTemplate.allCases.count)
        XCTAssertFalse(icons.contains(where: \.isEmpty))
        for template in ListTemplate.allCases {
            XCTAssertEqual(template.titleKey, "lists.template." + template.rawValue)
            XCTAssertEqual(template.hintKey, "lists.template." + template.rawValue + ".hint")
        }
        XCTAssertEqual(ListTemplate.shopping.systemImage, "cart")
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
