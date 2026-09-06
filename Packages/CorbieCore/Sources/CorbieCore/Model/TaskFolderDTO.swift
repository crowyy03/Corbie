import Foundation

public struct TaskFolderDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var spaceId: UUID?
    public var title: String
    public var subtitle: String?
    public var template: FolderTemplate
    public var anyoneCanCheck: Bool
    public var isPinnedShopping: Bool
    public var sortIndex: Int
    public var createdByMemberId: UUID?
    public var createdAt: Date?
    public var taskCount: Int
    public var doneCount: Int
    public var placeCount: Int

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        title: String = "",
        subtitle: String? = nil,
        template: FolderTemplate = .empty,
        anyoneCanCheck: Bool = true,
        isPinnedShopping: Bool = false,
        sortIndex: Int = 0,
        createdByMemberId: UUID? = nil,
        createdAt: Date? = nil,
        taskCount: Int = 0,
        doneCount: Int = 0,
        placeCount: Int = 0
    ) {
        self.id = id
        self.spaceId = spaceId
        self.title = title
        self.subtitle = subtitle
        self.template = template
        self.anyoneCanCheck = anyoneCanCheck
        self.isPinnedShopping = isPinnedShopping
        self.sortIndex = sortIndex
        self.createdByMemberId = createdByMemberId
        self.createdAt = createdAt
        self.taskCount = taskCount
        self.doneCount = doneCount
        self.placeCount = placeCount
    }

    public init(_ folder: TaskFolder) {
        let tasks = folder.tasks.filter { $0.archivedAt == nil }
        self.init(
            id: folder.id ?? UUID(),
            spaceId: folder.space?.id,
            title: folder.title ?? "",
            subtitle: folder.subtitle,
            template: folder.template,
            anyoneCanCheck: folder.anyoneCanCheck,
            isPinnedShopping: folder.isPinnedShopping,
            sortIndex: Int(folder.sortIndex),
            createdByMemberId: folder.createdByMemberId,
            createdAt: folder.createdAt,
            taskCount: tasks.count,
            doneCount: tasks.filter(\.isDone).count,
            placeCount: tasks.filter { $0.lat != nil && $0.lon != nil }.count
        )
    }

    public var hasPlaces: Bool { placeCount > 0 }
}
