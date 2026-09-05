import CorbieCore
import Foundation

struct TaskDueNotifications: Sendable {
    let scheduler: NotificationScheduler

    func sync(task: TaskDTO, prefs: NotificationPrefs, now: Date) async {
        guard prefs.taskDueToday, task.isDone == false, task.archivedAt == nil, task.dueAt != nil else {
            await scheduler.cancelTaskDueToday(taskId: task.id)
            return
        }
        guard (try? await scheduler.requestAuthorizationIfNeeded()) == true else {
            await scheduler.cancelTaskDueToday(taskId: task.id)
            return
        }
        _ = try? await scheduler.scheduleTaskDueToday(for: task, prefs: prefs, now: now)
    }

    func cancel(taskId: UUID) async {
        await scheduler.cancelTaskDueToday(taskId: taskId)
    }
}
