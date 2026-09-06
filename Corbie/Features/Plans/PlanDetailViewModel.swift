import CorbieCore
import Observation
import SwiftUI

@MainActor
@Observable
final class PlanDetailViewModel {
    var isAddingExpense = false
    var isEditingPlan = false
    var isConfirmingDelete = false
    private(set) var plan: PlanDTO?
    private(set) var expenses: [PlanExpenseDTO] = []

    @ObservationIgnored private let planId: UUID
    @ObservationIgnored private var environment: AppEnvironment?

    init(planId: UUID) {
        self.planId = planId
    }

    var totals: PlanTotals? {
        plan.map(PlanTotals.init(plan:))
    }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
    }

    func load() async {
        guard let environment else { return }
        do {
            plan = try await environment.repositories.plans.plan(id: planId)
            expenses = try await environment.repositories.plans.expenses(planId: planId)
        } catch {
            environment.report(error)
        }
    }

    func startAddingExpense() {
        guard plan != nil, let environment, environment.premiumGate.require(.create) else { return }
        isAddingExpense = true
    }

    func startEditing() {
        guard plan != nil, let environment, environment.premiumGate.require(.edit) else { return }
        isEditingPlan = true
    }

    func startDeleting() {
        guard plan != nil, let environment, environment.premiumGate.require(.edit) else { return }
        isConfirmingDelete = true
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

    func setStatus(_ status: PlanStatus) async {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        do {
            plan = try await environment.repositories.plans.setStatus(planId: planId, status: status)
        } catch {
            environment.report(error)
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
