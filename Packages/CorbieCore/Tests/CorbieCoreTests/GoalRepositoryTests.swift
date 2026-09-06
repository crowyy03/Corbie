import Foundation
import Testing
@testable import CorbieCore

@Suite struct GoalRepositoryTests {
    @Test func totalsUseTheStoredRateForEachExpense() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.goals
        let goal = try await repository.create(
            GoalDraft(
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
            goalId: goal.id,
            draft: GoalExpenseDraft(amount: 1200, currency: "USD", addedByMemberId: world.me.id)
        )
        let euro = try await repository.addExpense(
            goalId: goal.id,
            draft: GoalExpenseDraft(
                amount: 500,
                currency: "EUR",
                fxRateToGoalCurrency: 1.1,
                note: "Hotel",
                addedByMemberId: world.partner.id
            )
        )
        #expect(euro.amountInGoalCurrency == 550)
        #expect(euro.isConverted)

        let stored = try #require(try await repository.goal(id: goal.id))
        #expect(stored.savedAmount == 2400)
        #expect(stored.addedAmount == 1750)
        #expect(stored.totalSavedAmount == 4150)
        #expect(stored.leftAmount == 850)
        #expect(stored.isOverspent == false)
        #expect(stored.expenseCount == 2)
    }

    @Test func overspendIsReportedAgainstTheTarget() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.goals
        let goal = try await repository.create(
            GoalDraft(spaceId: world.space.id, title: "Kitchen", targetAmount: 1000, currency: "USD")
        )
        _ = try await repository.addExpense(goalId: goal.id, draft: GoalExpenseDraft(amount: 1340, currency: "USD"))
        let stored = try #require(try await repository.goal(id: goal.id))
        #expect(stored.isOverspent)
        #expect(stored.overspentAmount == 340)
    }

    @Test func deletingAnExpenseUpdatesTheTotals() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.goals
        let goal = try await repository.create(
            GoalDraft(spaceId: world.space.id, title: "Camera", targetAmount: 800, currency: "USD")
        )
        let expense = try await repository.addExpense(
            goalId: goal.id,
            draft: GoalExpenseDraft(amount: 100, currency: "USD")
        )
        try await repository.deleteExpense(id: expense.id)
        let stored = try #require(try await repository.goal(id: goal.id))
        #expect(stored.addedAmount == 0)
        #expect(try await repository.expenses(goalId: goal.id).isEmpty)
    }

    @Test func statusFiltersTheGoalList() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.goals
        let goal = try await repository.create(
            GoalDraft(spaceId: world.space.id, title: "Wedding", targetAmount: 10_000, currency: "USD")
        )
        _ = try await repository.setStatus(goalId: goal.id, status: .archived)
        #expect(try await repository.goals(spaceId: world.space.id).isEmpty)
        let archived = try await repository.goals(spaceId: world.space.id, statuses: [.archived])
        #expect(archived.map(\.id) == [goal.id])
    }

    @Test func rateMustBePositive() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.goals
        let goal = try await repository.create(
            GoalDraft(spaceId: world.space.id, title: "Bike", targetAmount: 500, currency: "USD")
        )
        await #expect(throws: CorbieError.invalidInput("fx rate must be positive")) {
            _ = try await repository.addExpense(
                goalId: goal.id,
                draft: GoalExpenseDraft(amount: 10, currency: "EUR", fxRateToGoalCurrency: 0)
            )
        }
    }
}
