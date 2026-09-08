import CorbieCore
import XCTest
@testable import Corbie

final class OpenSavingsTests: XCTestCase {
    private let usd = Locale(identifier: "en_US")
    private let space = UUID()

    private func openPlan(saved: Double = 0, added: Double = 0, expenses: Int = 0) -> PlanDTO {
        PlanDTO(
            id: UUID(),
            title: "The pot",
            type: .other,
            currency: "USD",
            savedAmount: saved,
            addedAmount: added,
            isOpenEnded: true,
            expenseCount: expenses
        )
    }

    @MainActor
    func testANewPlanWithATargetOnlySavesOnceTheAmountIsThere() {
        let model = PlanEditorViewModel(plan: nil)
        model.title = "Lisbon"
        XCTAssertEqual(model.kind, .targeted)
        XCTAssertFalse(model.canSave)

        model.targetAmount = 5000
        XCTAssertTrue(model.canSave)

        let draft = model.draft(spaceId: space, createdByMemberId: nil)
        XCTAssertFalse(draft.isOpenEnded)
        XCTAssertEqual(draft.targetAmount, 5000)
    }

    @MainActor
    func testSwitchingToOpenDropsTheTargetAndStillSaves() {
        let model = PlanEditorViewModel(plan: nil)
        model.title = "The pot"
        model.targetAmount = 5000
        model.kind = .open

        XCTAssertTrue(model.canSave)
        let draft = model.draft(spaceId: space, createdByMemberId: nil)
        XCTAssertTrue(draft.isOpenEnded)
        XCTAssertEqual(draft.targetAmount, 0)
    }

    @MainActor
    func testAnOpenPlanGoingBackToATargetHasToNameOne() {
        let model = PlanEditorViewModel(plan: openPlan(saved: 400))
        XCTAssertEqual(model.kind, .open)
        XCTAssertTrue(model.canSave)

        model.kind = .targeted
        XCTAssertFalse(model.canSave)

        model.targetAmount = 2000
        XCTAssertTrue(model.canSave)
        let updated = model.updated(openPlan(saved: 400))
        XCTAssertFalse(updated.isOpenEnded)
        XCTAssertEqual(updated.targetAmount, 2000)
        XCTAssertEqual(updated.savedAmount, 400)
    }

    @MainActor
    func testTakingMoneyOutTurnsTheContributionNegative() {
        let model = ExpenseEditorViewModel(plan: openPlan())
        model.amount = 120
        XCTAssertTrue(model.allowsWithdrawal)
        XCTAssertEqual(model.signedAmount, 120)

        model.isWithdrawal = true
        XCTAssertTrue(model.canSave)
        XCTAssertEqual(model.signedAmount, -120)

        let draft = model.draft(rate: 1.1, addedByMemberId: nil)
        XCTAssertEqual(draft.amount, -120)
        XCTAssertEqual(draft.fxRateToPlanCurrency, 1.1)
    }

    @MainActor
    func testAPlanWithATargetHasNoWayToTakeMoneyOut() {
        let plan = PlanDTO(id: UUID(), title: "Lisbon", type: .trip, targetAmount: 5000, currency: "USD")
        XCTAssertFalse(ExpenseEditorViewModel(plan: plan).allowsWithdrawal)
    }

    func testTheOpenCardCountsContributionsAndNamesTheMonthItStarted() {
        let october = Date(timeIntervalSince1970: 1_760_000_000)
        XCTAssertEqual(planContributions(count: 1), "1 contribution")
        XCTAssertEqual(planContributions(count: 6), "6 contributions")
        XCTAssertEqual(
            planOpenSubtitle(startedAt: october, contributionCount: 6, locale: usd),
            "since October 2025 \u{b7} 6 contributions"
        )
        XCTAssertEqual(planOpenSubtitle(startedAt: nil, contributionCount: 0, locale: usd), "0 contributions")
    }

    func testAnOpenPlanShowsNoProgressAndNoOverspend() {
        let totals = PlanTotals(plan: openPlan(saved: 400, added: 1240, expenses: 6))
        XCTAssertEqual(totals.saved, 1640)
        XCTAssertEqual(totals.progress, 0)
        XCTAssertEqual(totals.left, 0)
        XCTAssertFalse(totals.isOverspent)
        XCTAssertFalse(openPlan(saved: 400).showsProgress)
    }
}
