import Foundation

public enum TaskIntentRunner {
    @discardableResult
    public static func markDone(
        taskId: UUID,
        persistence: IntentPersistence = .shared,
        calendar: Calendar = .current,
        now: Date = Date()
    ) async throws -> TaskCompletion {
        let repositories = persistence.controller().repositories
        guard let task = try await repositories.tasks.task(id: taskId) else {
            throw CorbieError.notFound("task " + taskId.uuidString)
        }
        guard task.isDone == false else {
            return TaskCompletion(task: task)
        }
        let memberId = try? await persistence.currentMemberId()
        let completion = try await repositories.tasks.markDone(
            taskId: taskId,
            memberId: memberId ?? task.assigneeMemberId,
            at: now
        )
        guard let nextDueAt = RecurrenceEngine.nextOccurrence(
            for: completion.task,
            completedAt: now,
            calendar: calendar
        ) else {
            WidgetReloader.reloadNow()
            return TaskCompletion(task: completion.task)
        }
        _ = try await repositories.tasks.createNextOccurrence(of: taskId, dueAt: nextDueAt)
        WidgetReloader.reloadNow()
        return TaskCompletion(task: completion.task, nextOccurrenceDueAt: nextDueAt)
    }

    @discardableResult
    public static func take(
        taskId: UUID,
        persistence: IntentPersistence = .shared,
        now: Date = Date()
    ) async throws -> TaskDTO {
        let repositories = persistence.controller().repositories
        guard let memberId = try await persistence.currentMemberId() else {
            throw CorbieError.auth("no current member for the take intent")
        }
        let task = try await repositories.tasks.take(taskId: taskId, memberId: memberId, at: now)
        WidgetReloader.reloadNow()
        return task
    }

    @discardableResult
    public static func toggleShoppingItem(
        itemId: UUID,
        persistence: IntentPersistence = .shared,
        now: Date = Date()
    ) async throws -> ListItemDTO {
        let repositories = persistence.controller().repositories
        let memberId = try? await persistence.currentMemberId()
        let item = try await repositories.lists.toggleItem(itemId: itemId, memberId: memberId ?? nil, at: now)
        WidgetReloader.reloadNow()
        return item
    }

    public static func identifier(_ value: String) throws -> UUID {
        guard let id = UUID(uuidString: value) else {
            throw CorbieError.invalidInput("identifier " + value + " is not a uuid")
        }
        return id
    }
}

#if canImport(AppIntents)
import AppIntents

@available(iOS 17.0, macOS 14.0, *)
public struct ToggleTaskDoneIntent: AppIntent {
    public static let title: LocalizedStringResource = "intent.task.done.title"
    public static let isDiscoverable = false

    @Parameter(title: "intent.task.parameter.id")
    public var taskID: String

    public init() {
        taskID = ""
    }

    public init(taskID: UUID) {
        self.taskID = taskID.uuidString
    }

    public func perform() async throws -> some IntentResult {
        try await TaskIntentRunner.markDone(taskId: TaskIntentRunner.identifier(taskID))
        return .result()
    }
}
#endif
