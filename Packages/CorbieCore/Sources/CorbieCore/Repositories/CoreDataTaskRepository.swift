import CoreData
import Foundation

public struct CoreDataTaskRepository: TaskRepository {
    private let access: CoreDataAccess

    public init(stack: CoreDataStack) {
        access = CoreDataAccess(stack: stack)
    }

    public func create(_ draft: TaskDraft) async throws -> TaskDTO {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            throw CorbieError.invalidInput("task title is empty")
        }
        return try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: draft.spaceId, in: context)
            let folder: TaskFolder? = try draft.folderId.map { folderId in
                try ManagedFetch.require(TaskFolder.entityName, id: folderId, in: context)
            }
            let sortIndex = CoreDataTaskRepository.nextSortIndex(in: folder, space: space)
            let task = TaskItem(context: context)
            context.assign(task, toStoreOf: space)
            task.space = space
            task.folder = folder
            task.title = title
            task.note = draft.note
            task.assigneeMemberId = draft.assigneeMemberId
            task.dueAt = draft.dueAt
            task.recurrence = draft.recurrence
            task.placeName = draft.placeName
            task.address = draft.address
            task.lat = draft.lat.map(NSNumber.init(value:))
            task.lon = draft.lon.map(NSNumber.init(value:))
            task.sourceGoalId = draft.sourceGoalId
            task.sortIndex = sortIndex
            task.createdByMemberId = draft.createdByMemberId
            task.takenAt = draft.assigneeMemberId == nil ? nil : Date()
            return TaskDTO(task)
        }
    }

    public func update(_ task: TaskDTO) async throws -> TaskDTO {
        try await access.write { context in
            let entity: TaskItem = try ManagedFetch.require(TaskItem.entityName, id: task.id, in: context)
            entity.title = task.title
            entity.note = task.note
            entity.assigneeMemberId = task.assigneeMemberId
            entity.dueAt = task.dueAt
            entity.recurrence = task.recurrence
            entity.placeName = task.placeName
            entity.address = task.address
            entity.lat = task.lat.map(NSNumber.init(value:))
            entity.lon = task.lon.map(NSNumber.init(value:))
            entity.archivedAt = task.archivedAt
            return TaskDTO(entity)
        }
    }

    public func take(taskId: UUID, memberId: UUID, at date: Date) async throws -> TaskDTO {
        try await access.write { context in
            let task: TaskItem = try ManagedFetch.require(TaskItem.entityName, id: taskId, in: context)
            task.assigneeMemberId = memberId
            task.takenAt = date
            return TaskDTO(task)
        }
    }

    public func handBack(taskId: UUID) async throws -> TaskDTO {
        try await access.write { context in
            let task: TaskItem = try ManagedFetch.require(TaskItem.entityName, id: taskId, in: context)
            task.assigneeMemberId = nil
            return TaskDTO(task)
        }
    }

    public func markDone(taskId: UUID, memberId: UUID?, at date: Date) async throws -> TaskCompletion {
        try await access.write { context in
            let task: TaskItem = try ManagedFetch.require(TaskItem.entityName, id: taskId, in: context)
            try CoreDataTaskRepository.requireTickPermission(task, memberId: memberId)
            task.isDone = true
            task.doneByMemberId = memberId
            task.doneAt = date
            let dto = TaskDTO(task)
            return TaskCompletion(
                task: dto,
                nextOccurrenceDueAt: RecurrenceEngine.nextOccurrence(for: dto, completedAt: date)
            )
        }
    }

    public func setDone(taskId: UUID, isDone: Bool, memberId: UUID?, at date: Date) async throws -> TaskDTO {
        try await access.write { context in
            let task: TaskItem = try ManagedFetch.require(TaskItem.entityName, id: taskId, in: context)
            try CoreDataTaskRepository.requireTickPermission(task, memberId: memberId)
            task.isDone = isDone
            task.doneByMemberId = isDone ? memberId : nil
            task.doneAt = isDone ? date : nil
            return TaskDTO(task)
        }
    }

    public func createNextOccurrence(of taskId: UUID, dueAt: Date?) async throws -> TaskDTO {
        try await access.write { context in
            let source: TaskItem = try ManagedFetch.require(TaskItem.entityName, id: taskId, in: context)
            let next = TaskItem(context: context)
            context.assign(next, toStoreOf: source)
            next.space = source.space
            next.folder = source.folder
            next.title = source.title
            next.note = source.note
            next.assigneeMemberId = source.assigneeMemberId
            next.createdByMemberId = source.createdByMemberId
            next.recurrence = source.recurrence
            next.placeName = source.placeName
            next.address = source.address
            next.lat = source.lat
            next.lon = source.lon
            next.sortIndex = source.sortIndex
            next.dueAt = dueAt
            next.takenAt = source.assigneeMemberId == nil ? nil : Date()
            return TaskDTO(next)
        }
    }

    public func task(id: UUID) async throws -> TaskDTO? {
        try await access.read { context in
            let task: TaskItem? = try ManagedFetch.first(TaskItem.entityName, id: id, in: context)
            return task.map(TaskDTO.init)
        }
    }

    public func tasks(_ query: TaskQuery) async throws -> [TaskDTO] {
        try await access.read { context in
            let tasks: [TaskItem] = try ManagedFetch.all(
                TaskItem.entityName,
                predicate: CoreDataTaskRepository.predicate(for: query),
                sort: [NSSortDescriptor(key: "createdAt", ascending: true)],
                in: context
            )
            let dtos = tasks.map(TaskDTO.init)
            switch query.folder {
            case .all, .none:
                return dtos.sorted(by: CoreDataTaskRepository.dueDateOrder)
            case .folder:
                return dtos.sorted(by: CoreDataTaskRepository.folderOrder)
            }
        }
    }

    public func counts(
        spaceId: UUID,
        memberId: UUID?,
        partnerId: UUID?,
        folder: TaskFolderFilter
    ) async throws -> TaskCounts {
        let open = try await tasks(TaskQuery(spaceId: spaceId, folder: folder))
        return TaskCounts(
            all: open.count,
            mine: memberId.map { id in open.filter { $0.assigneeMemberId == id }.count } ?? 0,
            partner: partnerId.map { id in open.filter { $0.assigneeMemberId == id }.count } ?? 0,
            free: open.filter(\.isFree).count
        )
    }

    public func delete(id: UUID) async throws {
        try await access.write { context in
            guard let task: TaskItem = try ManagedFetch.first(TaskItem.entityName, id: id, in: context) else { return }
            context.delete(task)
        }
    }

    public func createFolder(_ draft: TaskFolderDraft) async throws -> TaskFolderDTO {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else {
            throw CorbieError.invalidInput("folder title is empty")
        }
        return try await access.write { context in
            let space: Space = try ManagedFetch.require(Space.entityName, id: draft.spaceId, in: context)
            let sortIndex = (space.folders.map(\.sortIndex).max() ?? -1) + 1
            let folder = TaskFolder(context: context)
            context.assign(folder, toStoreOf: space)
            folder.space = space
            folder.title = title
            folder.subtitle = draft.subtitle
            folder.template = draft.template
            folder.anyoneCanCheck = draft.anyoneCanCheck
            folder.isPinnedShopping = false
            folder.sortIndex = sortIndex
            folder.createdByMemberId = draft.createdByMemberId
            return TaskFolderDTO(folder)
        }
    }

    public func updateFolder(_ folder: TaskFolderDTO) async throws -> TaskFolderDTO {
        try await access.write { context in
            let entity: TaskFolder = try ManagedFetch.require(TaskFolder.entityName, id: folder.id, in: context)
            entity.title = folder.title
            entity.subtitle = folder.subtitle
            entity.template = folder.template
            entity.anyoneCanCheck = folder.anyoneCanCheck
            entity.sortIndex = Int32(folder.sortIndex)
            return TaskFolderDTO(entity)
        }
    }

    public func deleteFolder(id: UUID) async throws {
        try await access.write { context in
            guard let folder: TaskFolder = try ManagedFetch.first(TaskFolder.entityName, id: id, in: context) else {
                return
            }
            for task in folder.tasks {
                task.folder = nil
            }
            context.delete(folder)
        }
    }

    public func folder(id: UUID) async throws -> TaskFolderDTO? {
        try await access.read { context in
            let folder: TaskFolder? = try ManagedFetch.first(TaskFolder.entityName, id: id, in: context)
            return folder.map(TaskFolderDTO.init)
        }
    }

    public func folders(spaceId: UUID) async throws -> [TaskFolderDTO] {
        try await access.read { context in
            let folders: [TaskFolder] = try ManagedFetch.all(
                TaskFolder.entityName,
                predicate: ManagedFetch.spaceRelation(spaceId),
                in: context
            )
            return folders.map(TaskFolderDTO.init).sorted(by: CoreDataTaskRepository.folderListOrder)
        }
    }

    public func pinnedShoppingFolder(
        spaceId: UUID,
        title: String,
        createdByMemberId: UUID?
    ) async throws -> TaskFolderDTO {
        let name = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else {
            throw CorbieError.invalidInput("folder title is empty")
        }
        return try await access.write { context in
            let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                ManagedFetch.spaceRelation(spaceId),
                NSPredicate(format: "isPinnedShopping == YES")
            ])
            let existing: [TaskFolder] = try ManagedFetch.all(
                TaskFolder.entityName,
                predicate: predicate,
                sort: [NSSortDescriptor(key: "createdAt", ascending: true)],
                in: context
            )
            if let pinned = existing.first {
                return TaskFolderDTO(pinned)
            }
            let space: Space = try ManagedFetch.require(Space.entityName, id: spaceId, in: context)
            let folder = TaskFolder(context: context)
            context.assign(folder, toStoreOf: space)
            folder.space = space
            folder.title = name
            folder.template = .shopping
            folder.isPinnedShopping = true
            folder.anyoneCanCheck = true
            folder.sortIndex = 0
            folder.createdByMemberId = createdByMemberId
            return TaskFolderDTO(folder)
        }
    }

    public func move(taskId: UUID, toFolder folderId: UUID?) async throws -> TaskDTO {
        try await access.write { context in
            let task: TaskItem = try ManagedFetch.require(TaskItem.entityName, id: taskId, in: context)
            let folder: TaskFolder? = try folderId.map { id in
                try ManagedFetch.require(TaskFolder.entityName, id: id, in: context)
            }
            let sortIndex = CoreDataTaskRepository.nextSortIndex(in: folder, space: task.space)
            task.folder = folder
            task.sortIndex = sortIndex
            return TaskDTO(task)
        }
    }

    public func reorder(taskIds: [UUID]) async throws -> [TaskDTO] {
        try await access.write { context in
            var index: Int32 = 0
            var result: [TaskDTO] = []
            for id in taskIds {
                guard let task: TaskItem = try ManagedFetch.first(TaskItem.entityName, id: id, in: context) else {
                    continue
                }
                task.sortIndex = index
                index += 1
                result.append(TaskDTO(task))
            }
            return result
        }
    }

    public func clearDone(folderId: UUID) async throws -> [TaskDTO] {
        try await access.write { context in
            let inFolder = NSPredicate(format: "folder.id == %@", folderId as NSUUID)
            let done: [TaskItem] = try ManagedFetch.all(
                TaskItem.entityName,
                predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                    inFolder,
                    NSPredicate(format: "isDone == YES")
                ]),
                in: context
            )
            for task in done {
                context.delete(task)
            }
            let remaining: [TaskItem] = try ManagedFetch.all(
                TaskItem.entityName,
                predicate: inFolder,
                sort: [NSSortDescriptor(key: "sortIndex", ascending: true)],
                in: context
            )
            return remaining.filter { $0.isDeleted == false }.map(TaskDTO.init)
        }
    }

    private static func requireTickPermission(_ task: TaskItem, memberId: UUID?) throws {
        guard let folder = task.folder, folder.anyoneCanCheck == false else { return }
        let author = task.createdByMemberId ?? folder.createdByMemberId
        guard let memberId, let author, memberId == author else {
            throw CorbieError.invalidInput("only the author can tick tasks in this folder")
        }
    }

    private static func nextSortIndex(in folder: TaskFolder?, space: Space?) -> Int32 {
        let siblings = folder?.tasks ?? (space?.tasks.filter { $0.folder == nil } ?? [])
        return (siblings.map(\.sortIndex).max() ?? -1) + 1
    }

    private static func dueDateOrder(_ lhs: TaskDTO, _ rhs: TaskDTO) -> Bool {
        let left = lhs.dueAt ?? .distantFuture
        let right = rhs.dueAt ?? .distantFuture
        if left != right { return left < right }
        return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
    }

    private static func folderOrder(_ lhs: TaskDTO, _ rhs: TaskDTO) -> Bool {
        if lhs.isDone != rhs.isDone { return rhs.isDone }
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
    }

    private static func folderListOrder(_ lhs: TaskFolderDTO, _ rhs: TaskFolderDTO) -> Bool {
        if lhs.isPinnedShopping != rhs.isPinnedShopping { return lhs.isPinnedShopping }
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
    }

    private static func predicate(for query: TaskQuery) -> NSPredicate {
        var predicates = [ManagedFetch.spaceRelation(query.spaceId)]
        switch query.assignee {
        case .any:
            break
        case let .member(id):
            predicates.append(NSPredicate(format: "assigneeMemberId == %@", id as NSUUID))
        case .free:
            predicates.append(NSPredicate(format: "assigneeMemberId == nil"))
        }
        switch query.done {
        case .any:
            break
        case .done:
            predicates.append(NSPredicate(format: "isDone == YES"))
        case .notDone:
            predicates.append(NSPredicate(format: "isDone == NO"))
        }
        switch query.folder {
        case .all:
            break
        case .none:
            predicates.append(NSPredicate(format: "folder == nil"))
        case let .folder(id):
            predicates.append(NSPredicate(format: "folder.id == %@", id as NSUUID))
        }
        if query.includeArchived == false {
            predicates.append(NSPredicate(format: "archivedAt == nil"))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
