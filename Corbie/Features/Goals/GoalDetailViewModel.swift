import CorbieCore
import Observation
import SwiftUI

@MainActor
@Observable
final class GoalDetailViewModel {
    var isAddingExpense = false
    var isEditingGoal = false
    var isConfirmingDelete = false
    var stepTitle = ""
    var editedStep: GoalStepDTO?
    private(set) var goal: GoalDTO?
    private(set) var expenses: [GoalExpenseDTO] = []
    private(set) var steps: [GoalStepDTO] = []

    @ObservationIgnored private let goalId: UUID
    @ObservationIgnored private var environment: AppEnvironment?

    init(goalId: UUID) {
        self.goalId = goalId
    }

    var totals: GoalTotals? {
        goal.map(GoalTotals.init(goal:))
    }

    var isReadOnly: Bool { goal?.status == .archived }

    var canAddStep: Bool {
        stepTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
    }

    func load() async {
        guard let environment else { return }
        do {
            goal = try await environment.repositories.goals.goal(id: goalId)
            expenses = try await environment.repositories.goals.expenses(goalId: goalId)
            steps = try await environment.repositories.goals.steps(goalId: goalId)
        } catch {
            environment.report(error)
        }
    }

    func startAddingExpense() {
        guard goal != nil, isReadOnly == false, let environment, environment.premiumGate.require(.create) else {
            return
        }
        isAddingExpense = true
    }

    func startEditing() {
        guard goal != nil, isReadOnly == false, let environment, environment.premiumGate.require(.edit) else {
            return
        }
        isEditingGoal = true
    }

    func startDeleting() {
        guard goal != nil, let environment, environment.premiumGate.require(.edit) else { return }
        isConfirmingDelete = true
    }

    func startEditingStep(_ step: GoalStepDTO) {
        guard isReadOnly == false, let environment, environment.premiumGate.require(.edit) else { return }
        editedStep = step
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

    func addStep() async {
        let title = stepTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false, isReadOnly == false else { return }
        guard let environment, environment.premiumGate.require(.create) else { return }
        do {
            let step = try await environment.repositories.goals.addStep(
                goalId: goalId,
                draft: GoalStepDraft(title: title)
            )
            environment.analytics.record(.goalStepCreated(hasDue: step.hasDue))
            stepTitle = ""
        } catch {
            environment.report(error)
        }
        await load()
    }

    func toggleStep(_ step: GoalStepDTO) async {
        guard isReadOnly == false, let environment, environment.premiumGate.require(.edit) else { return }
        do {
            let updated = try await environment.repositories.goals.toggleStep(
                stepId: step.id,
                by: environment.currentMember?.id
            )
            if updated.isDone {
                environment.analytics.record(.goalStepDone)
            }
        } catch {
            environment.report(error)
        }
        await load()
    }

    func deleteSteps(at offsets: IndexSet) async {
        guard isReadOnly == false, let environment, environment.premiumGate.require(.edit) else { return }
        let doomed = offsets.map { steps[$0] }
        do {
            for step in doomed {
                try await environment.repositories.goals.deleteStep(id: step.id)
            }
        } catch {
            environment.report(error)
        }
        await load()
    }

    func moveSteps(from offsets: IndexSet, to destination: Int) async {
        guard isReadOnly == false, let environment, environment.premiumGate.require(.edit) else { return }
        do {
            steps = try await environment.repositories.goals.reorderSteps(
                goalId: goalId,
                orderedStepIds: goalStepOrder(steps, moving: offsets, to: destination)
            )
        } catch {
            environment.report(error)
            await load()
        }
    }

    func setStatus(_ status: GoalStatus) async -> Bool {
        guard let environment, environment.premiumGate.require(.edit) else { return false }
        do {
            goal = try await environment.repositories.goals.setStatus(goalId: goalId, status: status)
            if status == .completed {
                environment.analytics.record(.goalCompleted)
            }
            return true
        } catch {
            environment.report(error)
            return false
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
