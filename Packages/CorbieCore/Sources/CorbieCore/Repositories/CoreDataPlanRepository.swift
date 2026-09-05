import CoreData
import Foundation

public struct CoreDataPlanRepository: PlanRepository {
    private let access: CoreDataAccess

    public init(stack: CoreDataStack) {
        access = CoreDataAccess(stack: stack)
    }

    public func create(_ draft: PlanDraft) async throws -> PlanDTO {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            throw CorbieError.invalidInput("plan title is empty")
        }
        guard draft.targetAmount >= 0, draft.savedAmount >= 0 else {
            throw CorbieError.invalidInput("plan amounts cannot be negative")
        }
        return try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: draft.spaceId, in: context)
            let plan = Plan(context: context)
            plan.space = space
            plan.title = title
            plan.type = draft.type
            plan.targetAmount = draft.targetAmount
            plan.currency = draft.currency
            plan.savedAmount = draft.savedAmount
            plan.startAt = draft.startAt
            plan.endAt = draft.endAt
            plan.note = draft.note
            plan.createdByMemberId = draft.createdByMemberId
            plan.status = .active
            return PlanDTO(plan)
        }
    }

    public func update(_ plan: PlanDTO) async throws -> PlanDTO {
        try await access.write { context in
            let entity: Plan = try ManagedFetch.require(Plan.entityName, id: plan.id, in: context)
            entity.title = plan.title
            entity.type = plan.type
            entity.targetAmount = plan.targetAmount
            entity.currency = plan.currency
            entity.savedAmount = plan.savedAmount
            entity.startAt = plan.startAt
            entity.endAt = plan.endAt
            entity.note = plan.note
            entity.status = plan.status
            return PlanDTO(entity)
        }
    }

    public func setStatus(planId: UUID, status: PlanStatus) async throws -> PlanDTO {
        try await access.write { context in
            let plan: Plan = try ManagedFetch.require(Plan.entityName, id: planId, in: context)
            plan.status = status
            return PlanDTO(plan)
        }
    }

    public func plan(id: UUID) async throws -> PlanDTO? {
        try await access.read { context in
            let plan: Plan? = try ManagedFetch.first(Plan.entityName, id: id, in: context)
            return plan.map(PlanDTO.init)
        }
    }

    public func plans(spaceId: UUID, statuses: [PlanStatus]) async throws -> [PlanDTO] {
        try await access.read { context in
            var predicates = [ManagedFetch.spaceRelation(spaceId)]
            if statuses.isEmpty == false {
                predicates.append(NSPredicate(format: "statusRaw IN %@", statuses.map(\.rawValue)))
            }
            let plans: [Plan] = try ManagedFetch.all(
                Plan.entityName,
                predicate: NSCompoundPredicate(andPredicateWithSubpredicates: predicates),
                sort: [NSSortDescriptor(key: "createdAt", ascending: false)],
                in: context
            )
            return plans.map(PlanDTO.init)
        }
    }

    public func delete(id: UUID) async throws {
        try await access.write { context in
            guard let plan: Plan = try ManagedFetch.first(Plan.entityName, id: id, in: context) else { return }
            context.delete(plan)
        }
    }

    public func addExpense(planId: UUID, draft: ExpenseDraft) async throws -> PlanExpenseDTO {
        guard draft.fxRateToPlanCurrency > 0 else {
            throw CorbieError.invalidInput("fx rate must be positive")
        }
        return try await access.write { context in
            let plan: Plan = try ManagedFetch.require(Plan.entityName, id: planId, in: context)
            let expense = PlanExpense(context: context)
            expense.plan = plan
            expense.amount = draft.amount
            expense.currency = draft.currency
            expense.fxRateToPlanCurrency = draft.fxRateToPlanCurrency
            expense.amountInPlanCurrency = draft.amount * draft.fxRateToPlanCurrency
            expense.note = draft.note
            expense.date = draft.date
            expense.addedByMemberId = draft.addedByMemberId
            return PlanExpenseDTO(expense)
        }
    }

    public func expenses(planId: UUID) async throws -> [PlanExpenseDTO] {
        try await access.read { context in
            let expenses: [PlanExpense] = try ManagedFetch.all(
                PlanExpense.entityName,
                predicate: NSPredicate(format: "plan.id == %@", planId as NSUUID),
                sort: [NSSortDescriptor(key: "date", ascending: false)],
                in: context
            )
            return expenses.map(PlanExpenseDTO.init)
        }
    }

    public func deleteExpense(id: UUID) async throws {
        try await access.write { context in
            let expense: PlanExpense? = try ManagedFetch.first(PlanExpense.entityName, id: id, in: context)
            guard let expense else { return }
            context.delete(expense)
        }
    }
}
