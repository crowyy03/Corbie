import CorbieCore
import Observation
import SwiftUI

@MainActor
@Observable
final class PlanDetailViewModel {
    var isAddingExpense = false
    var isEditingPlan = false
    var isConfirmingDelete = false
    var stepTitle = ""
    var editedStep: PlanStepDTO?
    private(set) var plan: PlanDTO?
    private(set) var expenses: [PlanExpenseDTO] = []
    private(set) var steps: [PlanStepDTO] = []

    @ObservationIgnored private let planId: UUID
    @ObservationIgnored private var environment: AppEnvironment?

    init(planId: UUID) {
        self.planId = planId
    }

    var totals: PlanTotals? {
        plan.map(PlanTotals.init(plan:))
    }

    var isReadOnly: Bool { plan?.status == .archived }

    var canAddStep: Bool {
        stepTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
    }

    func load() async {
        guard let environment else { return }
        do {
            plan = try await environment.repositories.plans.plan(id: planId)
            expenses = try await environment.repositories.plans.expenses(planId: planId)
            steps = try await environment.repositories.plans.steps(planId: planId)
        } catch {
            environment.report(error)
        }
    }

    func startAddingExpense() {
        guard plan != nil, isReadOnly == false, let environment, environment.premiumGate.require(.create) else {
            return
        }
        isAddingExpense = true
    }

    func startEditing() {
        guard plan != nil, isReadOnly == false, let environment, environment.premiumGate.require(.edit) else {
            return
        }
        isEditingPlan = true
    }

    func startDeleting() {
        guard plan != nil, let environment, environment.premiumGate.require(.edit) else { return }
        isConfirmingDelete = true
    }

    func startEditingStep(_ step: PlanStepDTO) {
        guard isReadOnly == false, let environment, environment.premiumGate.require(.edit) else { return }
        editedStep = step
    }

    func deleteExpenses(at offsets: IndexSet) async {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        let doomed = offsets.map { expenses[$0] }
        do {
            for expense in doomed {
                try await environment.repositories.plans.deleteExpense(id: expense.id)
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
            let step = try await environment.repositories.plans.addStep(
                planId: planId,
                draft: PlanStepDraft(title: title)
            )
            environment.analytics.record(.planStepCreated(hasDue: step.hasDue))
            stepTitle = ""
        } catch {
            environment.report(error)
        }
        await load()
    }

    func toggleStep(_ step: PlanStepDTO) async {
        guard isReadOnly == false, let environment, environment.premiumGate.require(.edit) else { return }
        do {
            let updated = try await environment.repositories.plans.toggleStep(
                stepId: step.id,
                by: environment.currentMember?.id
            )
            if updated.isDone {
                environment.analytics.record(.planStepDone)
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
                try await environment.repositories.plans.deleteStep(id: step.id)
            }
        } catch {
            environment.report(error)
        }
        await load()
    }

    func moveSteps(from offsets: IndexSet, to destination: Int) async {
        guard isReadOnly == false, let environment, environment.premiumGate.require(.edit) else { return }
        do {
            steps = try await environment.repositories.plans.reorderSteps(
                planId: planId,
                orderedStepIds: planStepOrder(steps, moving: offsets, to: destination)
            )
        } catch {
            environment.report(error)
            await load()
        }
    }

    func setStatus(_ status: PlanStatus) async -> Bool {
        guard let environment, environment.premiumGate.require(.edit) else { return false }
        do {
            plan = try await environment.repositories.plans.setStatus(planId: planId, status: status)
            if status == .completed {
                environment.analytics.record(.planCompleted)
            }
            return true
        } catch {
            environment.report(error)
            return false
        }
    }

    func deletePlan() async -> Bool {
        guard let environment else { return false }
        do {
            try await environment.repositories.plans.delete(id: planId)
            return true
        } catch {
            environment.report(error)
            return false
        }
    }
}
