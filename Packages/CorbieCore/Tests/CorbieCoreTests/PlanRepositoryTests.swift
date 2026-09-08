import Foundation
import Testing
@testable import CorbieCore

@Suite struct PlanRepositoryTests {
    @Test func totalsUseTheStoredRateForEachExpense() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.plans
        let plan = try await repository.create(
            PlanDraft(
                spaceId: world.space.id,
                title: "Lisbon",
                type: .trip,
                targetAmount: 5000,
                currency: "USD",
                savedAmount: 2400,
                createdByMemberId: world.me.id
            )
        )

        _ = try await repository.addExpense(
            planId: plan.id,
            draft: PlanExpenseDraft(amount: 1200, currency: "USD", addedByMemberId: world.me.id)
        )
        let euro = try await repository.addExpense(
            planId: plan.id,
            draft: PlanExpenseDraft(
                amount: 500,
                currency: "EUR",
                fxRateToPlanCurrency: 1.1,
                note: "Hotel",
                addedByMemberId: world.partner.id
            )
        )
        #expect(euro.amountInPlanCurrency == 550)
        #expect(euro.isConverted)

        let stored = try #require(try await repository.plan(id: plan.id))
        #expect(stored.savedAmount == 2400)
        #expect(stored.addedAmount == 1750)
        #expect(stored.totalSavedAmount == 4150)
        #expect(stored.leftAmount == 850)
        #expect(stored.isOverspent == false)
        #expect(stored.expenseCount == 2)
    }

    @Test func overspendIsReportedAgainstTheTarget() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.plans
        let plan = try await repository.create(
            PlanDraft(spaceId: world.space.id, title: "Kitchen", targetAmount: 1000, currency: "USD")
        )
        _ = try await repository.addExpense(planId: plan.id, draft: PlanExpenseDraft(amount: 1340, currency: "USD"))
        let stored = try #require(try await repository.plan(id: plan.id))
        #expect(stored.isOverspent)
        #expect(stored.overspentAmount == 340)
    }

    @Test func deletingAnExpenseUpdatesTheTotals() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.plans
        let plan = try await repository.create(
            PlanDraft(spaceId: world.space.id, title: "Camera", targetAmount: 800, currency: "USD")
        )
        let expense = try await repository.addExpense(
            planId: plan.id,
            draft: PlanExpenseDraft(amount: 100, currency: "USD")
        )
        try await repository.deleteExpense(id: expense.id)
        let stored = try #require(try await repository.plan(id: plan.id))
        #expect(stored.addedAmount == 0)
        #expect(try await repository.expenses(planId: plan.id).isEmpty)
    }

    @Test func statusFiltersThePlanList() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.plans
        let plan = try await repository.create(
            PlanDraft(spaceId: world.space.id, title: "Wedding", targetAmount: 10_000, currency: "USD")
        )
        _ = try await repository.setStatus(planId: plan.id, status: .archived)
        #expect(try await repository.plans(spaceId: world.space.id).isEmpty)
        let archived = try await repository.plans(spaceId: world.space.id, statuses: [.archived])
        #expect(archived.map(\.id) == [plan.id])
    }

    @Test func rateMustBePositive() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.plans
        let plan = try await repository.create(
            PlanDraft(spaceId: world.space.id, title: "Bike", targetAmount: 500, currency: "USD")
        )
        await #expect(throws: CorbieError.invalidInput("fx rate must be positive")) {
            _ = try await repository.addExpense(
                planId: plan.id,
                draft: PlanExpenseDraft(amount: 10, currency: "EUR", fxRateToPlanCurrency: 0)
            )
        }
    }

    @Test func anOpenPlanJustAddsUpWithNoFinishLine() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.plans
        let plan = try await repository.create(
            PlanDraft(
                spaceId: world.space.id,
                title: "The pot",
                type: .other,
                targetAmount: 4000,
                currency: "USD",
                isOpenEnded: true,
                createdByMemberId: world.me.id
            )
        )
        #expect(plan.isOpenEnded)
        #expect(plan.targetAmount == 0)

        _ = try await repository.addExpense(
            planId: plan.id,
            draft: PlanExpenseDraft(amount: 300, currency: "USD", addedByMemberId: world.me.id)
        )
        _ = try await repository.addExpense(
            planId: plan.id,
            draft: PlanExpenseDraft(
                amount: 200,
                currency: "EUR",
                fxRateToPlanCurrency: 1.1,
                addedByMemberId: world.partner.id
            )
        )
        let stored = try #require(try await repository.plan(id: plan.id))
        #expect(stored.totalSavedAmount == 520)
        #expect(stored.expenseCount == 2)
        #expect(stored.progress == 0)
        #expect(stored.showsProgress == false)
        #expect(stored.leftAmount == 0)
        #expect(stored.isOverspent == false)
        #expect(stored.overspentAmount == 0)
    }

    @Test func takingMoneyOutOfAnOpenPlanIsANegativeContribution() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.plans
        let plan = try await repository.create(
            PlanDraft(
                spaceId: world.space.id,
                title: "The pot",
                type: .other,
                currency: "USD",
                isOpenEnded: true,
                createdByMemberId: world.me.id
            )
        )
        _ = try await repository.addExpense(
            planId: plan.id,
            draft: PlanExpenseDraft(amount: 500, currency: "USD", addedByMemberId: world.me.id)
        )
        _ = try await repository.addExpense(
            planId: plan.id,
            draft: PlanExpenseDraft(amount: 150, currency: "USD", addedByMemberId: world.partner.id)
        )
        _ = try await repository.addExpense(
            planId: plan.id,
            draft: PlanExpenseDraft(
                amount: 200,
                currency: "EUR",
                fxRateToPlanCurrency: 1.1,
                addedByMemberId: world.me.id
            )
        )
        let takenOut = try await repository.addExpense(
            planId: plan.id,
            draft: PlanExpenseDraft(amount: -120, currency: "USD", note: "Tyres", addedByMemberId: world.partner.id)
        )
        #expect(takenOut.isWithdrawal)
        #expect(takenOut.amountInPlanCurrency == -120)

        let stored = try #require(try await repository.plan(id: plan.id))
        #expect(stored.totalSavedAmount == 750)
        #expect(stored.expenseCount == 4)
        let expenses = try await repository.expenses(planId: plan.id)
        #expect(expenses.filter(\.isWithdrawal).count == 1)
    }

    @Test func aPlanWithATargetKeepsItsProgressAndOverspend() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.plans
        let plan = try await repository.create(
            PlanDraft(
                spaceId: world.space.id,
                title: "Lisbon",
                type: .trip,
                targetAmount: 1000,
                currency: "USD",
                savedAmount: 400,
                createdByMemberId: world.me.id
            )
        )
        #expect(plan.isOpenEnded == false)
        _ = try await repository.addExpense(
            planId: plan.id,
            draft: PlanExpenseDraft(amount: 800, currency: "USD", addedByMemberId: world.me.id)
        )
        let stored = try #require(try await repository.plan(id: plan.id))
        #expect(stored.progress == 1)
        #expect(stored.showsProgress)
        #expect(stored.isOverspent)
        #expect(stored.overspentAmount == 200)
        #expect(stored.leftAmount == 0)
    }

    @Test func aPlanCanBeTurnedIntoAnOpenOneAndBack() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.plans
        var plan = try await repository.create(
            PlanDraft(
                spaceId: world.space.id,
                title: "Lisbon",
                type: .trip,
                targetAmount: 1000,
                currency: "USD",
                createdByMemberId: world.me.id
            )
        )
        plan.isOpenEnded = true
        let opened = try await repository.update(plan)
        #expect(opened.isOpenEnded)
        #expect(opened.targetAmount == 0)

        var back = opened
        back.isOpenEnded = false
        back.targetAmount = 1500
        let targeted = try await repository.update(back)
        #expect(targeted.isOpenEnded == false)
        #expect(targeted.targetAmount == 1500)
        #expect(targeted.showsProgress)
    }
}
