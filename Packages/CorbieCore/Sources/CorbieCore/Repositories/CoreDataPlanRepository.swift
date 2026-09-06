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
            context.assign(plan, toStoreOf: space)
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

    public func addExpense(planId: UUID, draft: PlanExpenseDraft) async throws -> PlanExpenseDTO {
        guard draft.fxRateToPlanCurrency > 0 else {
            throw CorbieError.invalidInput("fx rate must be positive")
        }
        return try await access.write { context in
            let plan: Plan = try ManagedFetch.require(Plan.entityName, id: planId, in: context)
            let expense = PlanExpense(context: context)
            context.assign(expense, toStoreOf: plan)
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

    public func addStep(planId: UUID, draft: PlanStepDraft) async throws -> PlanStepDTO {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            throw CorbieError.invalidInput("plan step title is empty")
        }
        return try await access.write { context in
            let plan: Plan = try ManagedFetch.require(Plan.entityName, id: planId, in: context)
            let sortIndex = (plan.steps.map(\.sortIndex).max() ?? -1) + 1
            let step = PlanStep(context: context)
            context.assign(step, toStoreOf: plan)
            step.plan = plan
            step.title = title
            step.note = draft.note
            step.assigneeMemberId = draft.assigneeMemberId
            step.dueAt = draft.dueAt
            step.sortIndex = sortIndex
            return PlanStepDTO(step)
        }
    }

    public func updateStep(_ step: PlanStepDTO) async throws -> PlanStepDTO {
        try await access.write { context in
            let entity: PlanStep = try ManagedFetch.require(PlanStep.entityName, id: step.id, in: context)
            entity.title = step.title
            entity.note = step.note
            entity.assigneeMemberId = step.assigneeMemberId
            entity.dueAt = step.dueAt
            entity.sortIndex = Int32(step.sortIndex)
            return PlanStepDTO(entity)
        }
    }

    public func toggleStep(stepId: UUID, by memberId: UUID?, at date: Date) async throws -> PlanStepDTO {
        try await access.write { context in
            let step: PlanStep = try ManagedFetch.require(PlanStep.entityName, id: stepId, in: context)
            step.isDone.toggle()
            step.doneByMemberId = step.isDone ? memberId : nil
            step.doneAt = step.isDone ? date : nil
            return PlanStepDTO(step)
        }
    }

    public func deleteStep(id: UUID) async throws {
        try await access.write { context in
            guard let step: PlanStep = try ManagedFetch.first(PlanStep.entityName, id: id, in: context) else { return }
            context.delete(step)
        }
    }

    public func reorderSteps(planId: UUID, orderedStepIds: [UUID]) async throws -> [PlanStepDTO] {
        try await access.write { context in
            let steps: [PlanStep] = try ManagedFetch.all(
                PlanStep.entityName,
                predicate: NSPredicate(format: "plan.id == %@", planId as NSUUID),
                in: context
            )
            var byID: [UUID: PlanStep] = [:]
            for step in steps {
                if let id = step.id { byID[id] = step }
            }
            var index: Int32 = 0
            for id in orderedStepIds {
                guard let step = byID.removeValue(forKey: id) else { continue }
                step.sortIndex = index
                index += 1
            }
            for step in byID.values.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                step.sortIndex = index
                index += 1
            }
            return steps.map(PlanStepDTO.init).sorted(by: PlanStepDTO.checklistOrder)
        }
    }

    public func steps(planId: UUID) async throws -> [PlanStepDTO] {
        try await access.read { context in
            let steps: [PlanStep] = try ManagedFetch.all(
                PlanStep.entityName,
                predicate: NSPredicate(format: "plan.id == %@", planId as NSUUID),
                sort: [NSSortDescriptor(key: "sortIndex", ascending: true)],
                in: context
            )
            return steps.map(PlanStepDTO.init).sorted(by: PlanStepDTO.checklistOrder)
        }
    }

    public func datedSteps(spaceId: UUID) async throws -> [PlanStepDTO] {
        try await access.read { context in
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "plan.space.id == %@", spaceId as NSUUID),
                NSPredicate(format: "dueAt != nil")
            ])
            let steps: [PlanStep] = try ManagedFetch.all(
                PlanStep.entityName,
                predicate: predicate,
                sort: [NSSortDescriptor(key: "dueAt", ascending: true)],
                in: context
            )
            return steps.map(PlanStepDTO.init)
        }
    }
}
