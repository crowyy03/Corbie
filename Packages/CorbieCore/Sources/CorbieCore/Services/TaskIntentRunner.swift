import Foundation

public enum IntentNotifications {
    // UNUserNotificationCenter.current() raises when the process has no bundle identity
    public static func client() -> (any NotificationCenterClient)? {
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        #if canImport(UserNotifications)
        return SystemNotificationCenterClient()
        #else
        return nil
        #endif
    }
}

public enum TaskIntentRunner {
    @discardableResult
    public static func markDone(
        taskId: UUID,
        persistence: IntentPersistence = .shared,
        notifications: (any NotificationCenterClient)? = nil,
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
        await notifications?.removePending(identifiers: [NotificationIdentifier.taskDueToday(taskId: taskId)])
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
        let item = try await repositories.lists.toggleItem(itemId: itemId, memberId: memberId, at: now)
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
