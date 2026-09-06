import CoreData
import Foundation

public struct CoreDataGoalRepository: GoalRepository {
    private let access: CoreDataAccess

    public init(stack: CoreDataStack) {
        access = CoreDataAccess(stack: stack)
    }

    public func create(_ draft: GoalDraft) async throws -> GoalDTO {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            throw CorbieError.invalidInput("goal title is empty")
        }
        guard draft.targetAmount >= 0, draft.savedAmount >= 0 else {
            throw CorbieError.invalidInput("goal amounts cannot be negative")
        }
        return try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: draft.spaceId, in: context)
            let goal = Goal(context: context)
            context.assign(goal, toStoreOf: space)
            goal.space = space
            goal.title = title
            goal.type = draft.type
            goal.targetAmount = draft.targetAmount
            goal.currency = draft.currency
            goal.savedAmount = draft.savedAmount
            goal.startAt = draft.startAt
            goal.endAt = draft.endAt
            goal.note = draft.note
            goal.createdByMemberId = draft.createdByMemberId
            goal.status = .active
            return GoalDTO(goal)
        }
    }

    public func update(_ goal: GoalDTO) async throws -> GoalDTO {
        try await access.write { context in
            let entity: Goal = try ManagedFetch.require(Goal.entityName, id: goal.id, in: context)
            entity.title = goal.title
            entity.type = goal.type
            entity.targetAmount = goal.targetAmount
            entity.currency = goal.currency
            entity.savedAmount = goal.savedAmount
            entity.startAt = goal.startAt
            entity.endAt = goal.endAt
            entity.note = goal.note
            entity.status = goal.status
            return GoalDTO(entity)
        }
    }

    public func setStatus(goalId: UUID, status: GoalStatus) async throws -> GoalDTO {
        try await access.write { context in
            let goal: Goal = try ManagedFetch.require(Goal.entityName, id: goalId, in: context)
            goal.status = status
            return GoalDTO(goal)
        }
    }

    public func goal(id: UUID) async throws -> GoalDTO? {
        try await access.read { context in
            let goal: Goal? = try ManagedFetch.first(Goal.entityName, id: id, in: context)
            return goal.map(GoalDTO.init)
        }
    }

    public func goals(spaceId: UUID, statuses: [GoalStatus]) async throws -> [GoalDTO] {
        try await access.read { context in
            var predicates = [ManagedFetch.spaceRelation(spaceId)]
            if statuses.isEmpty == false {
                predicates.append(NSPredicate(format: "statusRaw IN %@", statuses.map(\.rawValue)))
            }
            let goals: [Goal] = try ManagedFetch.all(
                Goal.entityName,
                predicate: NSCompoundPredicate(andPredicateWithSubpredicates: predicates),
                sort: [NSSortDescriptor(key: "createdAt", ascending: false)],
                in: context
            )
            return goals.map(GoalDTO.init)
        }
    }

    public func delete(id: UUID) async throws {
        try await access.write { context in
            guard let goal: Goal = try ManagedFetch.first(Goal.entityName, id: id, in: context) else { return }
            context.delete(goal)
        }
    }

    public func addExpense(goalId: UUID, draft: GoalExpenseDraft) async throws -> GoalExpenseDTO {
        guard draft.fxRateToGoalCurrency > 0 else {
            throw CorbieError.invalidInput("fx rate must be positive")
        }
        return try await access.write { context in
            let goal: Goal = try ManagedFetch.require(Goal.entityName, id: goalId, in: context)
            let expense = GoalExpense(context: context)
            context.assign(expense, toStoreOf: goal)
            expense.goal = goal
            expense.amount = draft.amount
            expense.currency = draft.currency
            expense.fxRateToGoalCurrency = draft.fxRateToGoalCurrency
            expense.amountInGoalCurrency = draft.amount * draft.fxRateToGoalCurrency
            expense.note = draft.note
            expense.date = draft.date
            expense.addedByMemberId = draft.addedByMemberId
            return GoalExpenseDTO(expense)
        }
    }

    public func expenses(goalId: UUID) async throws -> [GoalExpenseDTO] {
        try await access.read { context in
            let expenses: [GoalExpense] = try ManagedFetch.all(
                GoalExpense.entityName,
                predicate: NSPredicate(format: "goal.id == %@", goalId as NSUUID),
                sort: [NSSortDescriptor(key: "date", ascending: false)],
                in: context
            )
            return expenses.map(GoalExpenseDTO.init)
        }
    }

    public func deleteExpense(id: UUID) async throws {
        try await access.write { context in
            let expense: GoalExpense? = try ManagedFetch.first(GoalExpense.entityName, id: id, in: context)
            guard let expense else { return }
            context.delete(expense)
        }
    }

    public func addStep(goalId: UUID, draft: GoalStepDraft) async throws -> GoalStepDTO {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            throw CorbieError.invalidInput("goal step title is empty")
        }
        return try await access.write { context in
            let goal: Goal = try ManagedFetch.require(Goal.entityName, id: goalId, in: context)
            let sortIndex = (goal.steps.map(\.sortIndex).max() ?? -1) + 1
            let step = GoalStep(context: context)
            context.assign(step, toStoreOf: goal)
            step.goal = goal
            step.title = title
            step.note = draft.note
            step.assigneeMemberId = draft.assigneeMemberId
            step.dueAt = draft.dueAt
            step.sortIndex = sortIndex
            return GoalStepDTO(step)
        }
    }

    public func updateStep(_ step: GoalStepDTO) async throws -> GoalStepDTO {
        try await access.write { context in
            let entity: GoalStep = try ManagedFetch.require(GoalStep.entityName, id: step.id, in: context)
            entity.title = step.title
            entity.note = step.note
            entity.assigneeMemberId = step.assigneeMemberId
            entity.dueAt = step.dueAt
            entity.sortIndex = Int32(step.sortIndex)
            return GoalStepDTO(entity)
        }
    }

    public func toggleStep(stepId: UUID, by memberId: UUID?, at date: Date) async throws -> GoalStepDTO {
        try await access.write { context in
            let step: GoalStep = try ManagedFetch.require(GoalStep.entityName, id: stepId, in: context)
            step.isDone.toggle()
            step.doneByMemberId = step.isDone ? memberId : nil
            step.doneAt = step.isDone ? date : nil
            return GoalStepDTO(step)
        }
    }

    public func deleteStep(id: UUID) async throws {
        try await access.write { context in
            guard let step: GoalStep = try ManagedFetch.first(GoalStep.entityName, id: id, in: context) else { return }
            context.delete(step)
        }
    }

    public func reorderSteps(goalId: UUID, orderedStepIds: [UUID]) async throws -> [GoalStepDTO] {
        try await access.write { context in
            let steps: [GoalStep] = try ManagedFetch.all(
                GoalStep.entityName,
                predicate: NSPredicate(format: "goal.id == %@", goalId as NSUUID),
                in: context
            )
            var byID: [UUID: GoalStep] = [:]
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
            return steps.sorted { $0.sortIndex < $1.sortIndex }.map(GoalStepDTO.init)
        }
    }

    public func steps(goalId: UUID) async throws -> [GoalStepDTO] {
        try await access.read { context in
            let steps: [GoalStep] = try ManagedFetch.all(
                GoalStep.entityName,
                predicate: NSPredicate(format: "goal.id == %@", goalId as NSUUID),
                sort: [NSSortDescriptor(key: "sortIndex", ascending: true)],
                in: context
            )
            return steps.map(GoalStepDTO.init)
        }
    }

    public func datedSteps(spaceId: UUID) async throws -> [GoalStepDTO] {
        try await access.read { context in
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "goal.space.id == %@", spaceId as NSUUID),
                NSPredicate(format: "dueAt != nil")
            ])
            let steps: [GoalStep] = try ManagedFetch.all(
                GoalStep.entityName,
                predicate: predicate,
                sort: [NSSortDescriptor(key: "dueAt", ascending: true)],
                in: context
            )
            return steps.map(GoalStepDTO.init)
        }
    }
}
