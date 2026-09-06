import CorbieCore
import Observation
import SwiftUI

@MainActor
@Observable
final class GoalDetailViewModel {
    var isAddingExpense = false
    var isEditingGoal = false
    var isConfirmingDelete = false
    private(set) var goal: GoalDTO?
    private(set) var expenses: [GoalExpenseDTO] = []

    @ObservationIgnored private let goalId: UUID
    @ObservationIgnored private var environment: AppEnvironment?

    init(goalId: UUID) {
        self.goalId = goalId
    }

    var totals: GoalTotals? {
        goal.map(GoalTotals.init(goal:))
    }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
    }

    func load() async {
        guard let environment else { return }
        do {
            goal = try await environment.repositories.goals.goal(id: goalId)
            expenses = try await environment.repositories.goals.expenses(goalId: goalId)
        } catch {
            environment.report(error)
        }
    }

    func startAddingExpense() {
        guard goal != nil, let environment, environment.premiumGate.require(.create) else { return }
        isAddingExpense = true
    }

    func startEditing() {
        guard goal != nil, let environment, environment.premiumGate.require(.edit) else { return }
        isEditingGoal = true
    }

    func startDeleting() {
        guard goal != nil, let environment, environment.premiumGate.require(.edit) else { return }
        isConfirmingDelete = true
    }

    func deleteExpenses(at offsets: IndexSet) async {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        let doomed = offsets.map { expenses[$0] }
        do {
            for expense in doomed {
                try await environment.repositories.goals.deleteExpense(id: expense.id)
            }
        } catch {
            environment.report(error)
        }
        await load()
    }

    func setStatus(_ status: GoalStatus) async {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        do {
            goal = try await environment.repositories.goals.setStatus(goalId: goalId, status: status)
            if status == .completed {
                environment.analytics.record(.goalCompleted)
            }
        } catch {
            environment.report(error)
        }
    }

    func deleteGoal() async -> Bool {
        guard let environment else { return false }
        do {
            try await environment.repositories.goals.delete(id: goalId)
            return true
        } catch {
            environment.report(error)
            return false
        }
    }
}
