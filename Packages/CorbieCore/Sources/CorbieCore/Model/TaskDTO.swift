import Foundation

public struct TaskDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var spaceId: UUID?
    public var folderId: UUID?
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
    public var placeName: String?
    public var address: String?
    public var lat: Double?
    public var lon: Double?
    public var sortIndex: Int
    public var sourceGoalId: UUID?
    public var archivedAt: Date?
    public var createdAt: Date?

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        folderId: UUID? = nil,
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
        placeName: String? = nil,
        address: String? = nil,
        lat: Double? = nil,
        lon: Double? = nil,
        sortIndex: Int = 0,
        sourceGoalId: UUID? = nil,
        archivedAt: Date? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.folderId = folderId
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
        self.placeName = placeName
        self.address = address
        self.lat = lat
        self.lon = lon
        self.sortIndex = sortIndex
        self.sourceGoalId = sourceGoalId
        self.archivedAt = archivedAt
        self.createdAt = createdAt
    }

    public init(_ task: TaskItem) {
        self.init(
            id: task.id ?? UUID(),
            spaceId: task.space?.id,
            folderId: task.folder?.id,
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
            placeName: task.placeName,
            address: task.address,
            lat: task.lat?.doubleValue,
            lon: task.lon?.doubleValue,
            sortIndex: Int(task.sortIndex),
            sourceGoalId: task.sourceGoalId,
            archivedAt: task.archivedAt,
            createdAt: task.createdAt
        )
    }

    public var isFree: Bool { assigneeMemberId == nil }

    public var hasPlace: Bool { lat != nil && lon != nil }
}
