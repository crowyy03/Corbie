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
            draft: ExpenseDraft(amount: 1200, currency: "USD", addedByMemberId: world.me.id)
        )
        let euro = try await repository.addExpense(
            planId: plan.id,
            draft: ExpenseDraft(
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
        #expect(stored.spentAmount == 1750)
        #expect(stored.leftAmount == 2600)
        #expect(stored.isOverspent == false)
        #expect(stored.expenseCount == 2)
    }

    @Test func overspendIsReportedAgainstTheTarget() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.plans
        let plan = try await repository.create(
            PlanDraft(spaceId: world.space.id, title: "Kitchen", targetAmount: 1000, currency: "USD")
        )
        _ = try await repository.addExpense(planId: plan.id, draft: ExpenseDraft(amount: 1340, currency: "USD"))
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
            draft: ExpenseDraft(amount: 100, currency: "USD")
        )
        try await repository.deleteExpense(id: expense.id)
        let stored = try #require(try await repository.plan(id: plan.id))
        #expect(stored.spentAmount == 0)
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
                draft: ExpenseDraft(amount: 10, currency: "EUR", fxRateToPlanCurrency: 0)
            )
        }
    }
}
