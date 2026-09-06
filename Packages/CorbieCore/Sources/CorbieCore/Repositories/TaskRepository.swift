import Foundation

public struct TaskDraft: Sendable, Equatable {
    public var spaceId: UUID
    public var title: String
    public var note: String?
    public var assigneeMemberId: UUID?
    public var dueAt: Date?
    public var recurrence: Recurrence
    public var folderId: UUID?
    public var placeName: String?
    public var address: String?
    public var lat: Double?
    public var lon: Double?
    public var sourceGoalId: UUID?
    public var createdByMemberId: UUID?

    public init(
        spaceId: UUID,
        title: String,
        note: String? = nil,
        assigneeMemberId: UUID? = nil,
        dueAt: Date? = nil,
        recurrence: Recurrence = .none,
        folderId: UUID? = nil,
        placeName: String? = nil,
        address: String? = nil,
        lat: Double? = nil,
        lon: Double? = nil,
        sourceGoalId: UUID? = nil,
        createdByMemberId: UUID? = nil
    ) {
        self.spaceId = spaceId
        self.title = title
        self.note = note
        self.assigneeMemberId = assigneeMemberId
        self.dueAt = dueAt
        self.recurrence = recurrence
        self.folderId = folderId
        self.placeName = placeName
        self.address = address
        self.lat = lat
        self.lon = lon
        self.sourceGoalId = sourceGoalId
        self.createdByMemberId = createdByMemberId
    }
}

public struct TaskFolderDraft: Sendable, Equatable {
    public var spaceId: UUID
    public var title: String
    public var subtitle: String?
    public var template: FolderTemplate
    public var anyoneCanCheck: Bool
    public var createdByMemberId: UUID?

    public init(
        spaceId: UUID,
        title: String,
        subtitle: String? = nil,
        template: FolderTemplate = .empty,
        anyoneCanCheck: Bool = true,
        createdByMemberId: UUID? = nil
    ) {
        self.spaceId = spaceId
        self.title = title
        self.subtitle = subtitle
        self.template = template
        self.anyoneCanCheck = anyoneCanCheck
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

public enum TaskFolderFilter: Sendable, Equatable {
    case all
    case none
    case folder(UUID)
}

public struct TaskQuery: Sendable, Equatable {
    public var spaceId: UUID
    public var assignee: TaskAssigneeFilter
    public var done: TaskDoneFilter
    public var folder: TaskFolderFilter
    public var includeArchived: Bool

    public init(
        spaceId: UUID,
        assignee: TaskAssigneeFilter = .any,
        done: TaskDoneFilter = .notDone,
        folder: TaskFolderFilter = .none,
        includeArchived: Bool = false
    ) {
        self.spaceId = spaceId
        self.assignee = assignee
        self.done = done
        self.folder = folder
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
    func setDone(taskId: UUID, isDone: Bool, memberId: UUID?, at date: Date) async throws -> TaskDTO
    func createNextOccurrence(of taskId: UUID, dueAt: Date?) async throws -> TaskDTO
    func task(id: UUID) async throws -> TaskDTO?
    func tasks(_ query: TaskQuery) async throws -> [TaskDTO]
    func counts(spaceId: UUID, memberId: UUID?, partnerId: UUID?, folder: TaskFolderFilter) async throws -> TaskCounts
    func delete(id: UUID) async throws

    func createFolder(_ draft: TaskFolderDraft) async throws -> TaskFolderDTO
    func updateFolder(_ folder: TaskFolderDTO) async throws -> TaskFolderDTO
    func deleteFolder(id: UUID) async throws
    func folder(id: UUID) async throws -> TaskFolderDTO?
    func folders(spaceId: UUID) async throws -> [TaskFolderDTO]
    func pinnedShoppingFolder(spaceId: UUID, title: String, createdByMemberId: UUID?) async throws -> TaskFolderDTO
    func move(taskId: UUID, toFolder folderId: UUID?) async throws -> TaskDTO
    func reorder(taskIds: [UUID]) async throws -> [TaskDTO]
    func clearDone(folderId: UUID) async throws -> [TaskDTO]
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

    public func setDone(taskId: UUID, isDone: Bool, memberId: UUID?) async throws -> TaskDTO {
        try await setDone(taskId: taskId, isDone: isDone, memberId: memberId, at: Date())
    }

    public func pinnedShoppingFolder(spaceId: UUID, title: String) async throws -> TaskFolderDTO {
        try await pinnedShoppingFolder(spaceId: spaceId, title: title, createdByMemberId: nil)
    }

    public func counts(spaceId: UUID, memberId: UUID?, partnerId: UUID?) async throws -> TaskCounts {
        try await counts(spaceId: spaceId, memberId: memberId, partnerId: partnerId, folder: .none)
    }
}
