import Foundation

public enum UnifiedTaskSource: Sendable, Equatable, Hashable {
    case task
    case planStep(planTitle: String)
}

public struct UnifiedTask: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let note: String?
    public let assigneeMemberId: UUID?
    public let dueAt: Date?
    public let isDone: Bool
    public let doneByMemberId: UUID?
    public let createdAt: Date?
    public let source: UnifiedTaskSource

    public init(
        id: UUID,
        title: String,
        note: String? = nil,
        assigneeMemberId: UUID? = nil,
        dueAt: Date? = nil,
        isDone: Bool = false,
        doneByMemberId: UUID? = nil,
        createdAt: Date? = nil,
        source: UnifiedTaskSource
    ) {
        self.id = id
        self.title = title
        self.note = note
        self.assigneeMemberId = assigneeMemberId
        self.dueAt = dueAt
        self.isDone = isDone
        self.doneByMemberId = doneByMemberId
        self.createdAt = createdAt
        self.source = source
    }

    public init(_ task: TaskDTO) {
        self.init(
            id: task.id,
            title: task.title,
            note: task.note,
            assigneeMemberId: task.assigneeMemberId,
            dueAt: task.dueAt,
            isDone: task.isDone,
            doneByMemberId: task.doneByMemberId,
            createdAt: task.createdAt,
            source: .task
        )
    }

    public init(_ step: PlanStepDTO) {
        self.init(
            id: step.id,
            title: step.title,
            note: step.note,
            assigneeMemberId: step.assigneeMemberId,
            dueAt: step.dueAt,
            isDone: step.isDone,
            doneByMemberId: step.doneByMemberId,
            createdAt: step.createdAt,
            source: .planStep(planTitle: step.planTitle)
        )
    }

    public var isFree: Bool { assigneeMemberId == nil }

    public var planTitle: String? {
        switch source {
        case .task: return nil
        case let .planStep(planTitle): return planTitle
        }
    }
}

public struct UnifiedTaskProvider: Sendable {
    private let tasks: any TaskRepository
    private let plans: any PlanRepository

    public init(tasks: any TaskRepository, plans: any PlanRepository) {
        self.tasks = tasks
        self.plans = plans
    }

    public init(repositories: Repositories) {
        self.init(tasks: repositories.tasks, plans: repositories.plans)
    }

    public func unifiedTasks(_ query: TaskQuery) async throws -> [UnifiedTask] {
        let plain = try await tasks.tasks(query).map(UnifiedTask.init)
        let steps = try await plans.datedSteps(spaceId: query.spaceId)
            .filter { UnifiedTaskProvider.matches($0, query: query) }
            .map(UnifiedTask.init)
        return (plain + steps).sorted(by: UnifiedTaskProvider.order)
    }

    @discardableResult
    public func toggleDone(_ item: UnifiedTask, by memberId: UUID?, at date: Date = Date()) async throws -> UnifiedTask {
        switch item.source {
        case .task:
            let updated = try await tasks.setDone(
                taskId: item.id,
                isDone: item.isDone == false,
                memberId: memberId,
                at: date
            )
            return UnifiedTask(updated)
        case .planStep:
            let updated = try await plans.toggleStep(stepId: item.id, by: memberId, at: date)
            return UnifiedTask(updated)
        }
    }

    private static func matches(_ step: PlanStepDTO, query: TaskQuery) -> Bool {
        switch query.done {
        case .any:
            break
        case .done:
            if step.isDone == false { return false }
        case .notDone:
            if step.isDone { return false }
        }
        switch query.assignee {
        case .any:
            return true
        case let .member(id):
            return step.assigneeMemberId == id
        case .free:
            return step.assigneeMemberId == nil
        }
    }

    private static func order(_ lhs: UnifiedTask, _ rhs: UnifiedTask) -> Bool {
        let left = lhs.dueAt ?? .distantFuture
        let right = rhs.dueAt ?? .distantFuture
        if left != right { return left < right }
        let leftCreated = lhs.createdAt ?? .distantPast
        let rightCreated = rhs.createdAt ?? .distantPast
        if leftCreated != rightCreated { return leftCreated < rightCreated }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}
