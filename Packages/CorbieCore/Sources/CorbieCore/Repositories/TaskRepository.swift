import Foundation

public struct TaskDraft: Sendable, Equatable {
    public var spaceId: UUID
    public var title: String
    public var note: String?
    public var assigneeMemberId: UUID?
    public var dueAt: Date?
    public var recurrence: Recurrence
    public var createdByMemberId: UUID?

    public init(
        spaceId: UUID,
        title: String,
        note: String? = nil,
        assigneeMemberId: UUID? = nil,
        dueAt: Date? = nil,
        recurrence: Recurrence = .none,
        createdByMemberId: UUID? = nil
    ) {
        self.spaceId = spaceId
        self.title = title
        self.note = note
        self.assigneeMemberId = assigneeMemberId
        self.dueAt = dueAt
        self.recurrence = recurrence
        self.createdByMemberId = createdByMemberId
    }
}

public enum TaskAssigneeFilter: Sendable, Equatable {
    case any
    case member(UUID)
    case free
}

public enum TaskDoneFilter: Sendable, Equatable {
    case any
    case done
    case notDone
}

public struct TaskQuery: Sendable, Equatable {
    public var spaceId: UUID
    public var assignee: TaskAssigneeFilter
    public var done: TaskDoneFilter
    public var includeArchived: Bool

    public init(
        spaceId: UUID,
        assignee: TaskAssigneeFilter = .any,
        done: TaskDoneFilter = .notDone,
        includeArchived: Bool = false
    ) {
        self.spaceId = spaceId
        self.assignee = assignee
        self.done = done
        self.includeArchived = includeArchived
    }
}

public struct TaskCompletion: Sendable, Equatable {
    public var task: TaskDTO
    public var nextOccurrenceDueAt: Date?

    public init(task: TaskDTO, nextOccurrenceDueAt: Date? = nil) {
        self.task = task
        self.nextOccurrenceDueAt = nextOccurrenceDueAt
    }

    public var isNextOccurrenceDue: Bool { nextOccurrenceDueAt != nil }
}

public protocol TaskRepository: Sendable {
    func create(_ draft: TaskDraft) async throws -> TaskDTO
    func update(_ task: TaskDTO) async throws -> TaskDTO
    func take(taskId: UUID, memberId: UUID, at date: Date) async throws -> TaskDTO
    func handBack(taskId: UUID) async throws -> TaskDTO
    func markDone(taskId: UUID, memberId: UUID?, at date: Date) async throws -> TaskCompletion
    func createNextOccurrence(of taskId: UUID, dueAt: Date?) async throws -> TaskDTO
    func task(id: UUID) async throws -> TaskDTO?
    func tasks(_ query: TaskQuery) async throws -> [TaskDTO]
    func counts(spaceId: UUID, memberId: UUID?) async throws -> TaskCounts
    func delete(id: UUID) async throws
}

public struct TaskCounts: Sendable, Equatable {
    public var all: Int
    public var mine: Int
    public var partner: Int
    public var free: Int

    public init(all: Int = 0, mine: Int = 0, partner: Int = 0, free: Int = 0) {
        self.all = all
        self.mine = mine
        self.partner = partner
        self.free = free
    }
}

extension TaskRepository {
    public func take(taskId: UUID, memberId: UUID) async throws -> TaskDTO {
        try await take(taskId: taskId, memberId: memberId, at: Date())
    }

    public func markDone(taskId: UUID, memberId: UUID?) async throws -> TaskCompletion {
        try await markDone(taskId: taskId, memberId: memberId, at: Date())
    }
}
