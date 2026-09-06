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
            let task = TaskItem(context: context)
            context.assign(task, toStoreOf: space)
            task.space = space
            task.title = title
            task.note = draft.note
            task.assigneeMemberId = draft.assigneeMemberId
            task.dueAt = draft.dueAt
            task.recurrence = draft.recurrence
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

    public func markDone(
        taskId: UUID,
        memberId: UUID?,
        at date: Date,
        calendar: Calendar
    ) async throws -> TaskCompletion {
        try await access.write { context in
            let task: TaskItem = try ManagedFetch.require(TaskItem.entityName, id: taskId, in: context)
            task.isDone = true
            task.doneByMemberId = memberId
            task.doneAt = date
            let dto = TaskDTO(task)
            return TaskCompletion(
                task: dto,
                nextOccurrenceDueAt: RecurrenceEngine.nextOccurrence(for: dto, completedAt: date, calendar: calendar)
            )
        }
    }

    public func setDone(taskId: UUID, isDone: Bool, memberId: UUID?, at date: Date) async throws -> TaskDTO {
        try await access.write { context in
            let task: TaskItem = try ManagedFetch.require(TaskItem.entityName, id: taskId, in: context)
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
            next.title = source.title
            next.note = source.note
            next.assigneeMemberId = source.assigneeMemberId
            next.createdByMemberId = source.createdByMemberId
            next.recurrence = source.recurrence
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
            return tasks.map(TaskDTO.init).sorted(by: CoreDataTaskRepository.dueDateOrder)
        }
    }

    public func counts(spaceId: UUID, memberId: UUID?, partnerId: UUID?) async throws -> TaskCounts {
        let open = try await tasks(TaskQuery(spaceId: spaceId))
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

    private static func dueDateOrder(_ lhs: TaskDTO, _ rhs: TaskDTO) -> Bool {
        let left = lhs.dueAt ?? .distantFuture
        let right = rhs.dueAt ?? .distantFuture
        if left != right { return left < right }
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
        if query.includeArchived == false {
            predicates.append(NSPredicate(format: "archivedAt == nil"))
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}
