import Foundation

public struct TaskDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var spaceId: UUID?
    public var title: String
    public var note: String?
    public var assigneeMemberId: UUID?
    public var dueAt: Date?
    public var isDone: Bool
    public var doneByMemberId: UUID?
    public var doneAt: Date?
    public var createdByMemberId: UUID?
    public var takenAt: Date?
    public var recurrence: Recurrence
    public var archivedAt: Date?
    public var createdAt: Date?

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        title: String = "",
        note: String? = nil,
        assigneeMemberId: UUID? = nil,
        dueAt: Date? = nil,
        isDone: Bool = false,
        doneByMemberId: UUID? = nil,
        doneAt: Date? = nil,
        createdByMemberId: UUID? = nil,
        takenAt: Date? = nil,
        recurrence: Recurrence = .none,
        archivedAt: Date? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.title = title
        self.note = note
        self.assigneeMemberId = assigneeMemberId
        self.dueAt = dueAt
        self.isDone = isDone
        self.doneByMemberId = doneByMemberId
        self.doneAt = doneAt
        self.createdByMemberId = createdByMemberId
        self.takenAt = takenAt
        self.recurrence = recurrence
        self.archivedAt = archivedAt
        self.createdAt = createdAt
    }

    public init(_ task: TaskItem) {
        self.init(
            id: task.id ?? UUID(),
            spaceId: task.space?.id,
            title: task.title ?? "",
            note: task.note,
            assigneeMemberId: task.assigneeMemberId,
            dueAt: task.dueAt,
            isDone: task.isDone,
            doneByMemberId: task.doneByMemberId,
            doneAt: task.doneAt,
            createdByMemberId: task.createdByMemberId,
            takenAt: task.takenAt,
            recurrence: task.recurrence,
            archivedAt: task.archivedAt,
            createdAt: task.createdAt
        )
    }

    public var isFree: Bool { assigneeMemberId == nil }
}
