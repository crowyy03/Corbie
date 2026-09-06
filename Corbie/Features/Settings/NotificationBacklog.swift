import CorbieCore
import Foundation

@MainActor
enum NotificationBacklog {
    static func resync(_ environment: AppEnvironment, now: Date = Date()) async {
        guard let space = environment.space, let member = environment.currentMember else { return }
        let prefs = member.notificationPrefs
        let scheduler = environment.notifications
        await scheduler.cancelDisabled(in: prefs)
        await rescheduleTasks(environment, spaceId: space.id, prefs: prefs, now: now)
        await rescheduleEvents(environment, spaceId: space.id, prefs: prefs, now: now)
        await rescheduleCapsules(environment, spaceId: space.id, member: member, prefs: prefs, now: now)
    }

    private static func rescheduleTasks(
        _ environment: AppEnvironment,
        spaceId: UUID,
        prefs: NotificationPrefs,
        now: Date
    ) async {
        guard prefs.taskDueToday else { return }
        guard let tasks = try? await environment.repositories.tasks.tasks(TaskQuery(spaceId: spaceId)) else { return }
        for task in tasks where task.dueAt != nil {
            _ = try? await environment.notifications.scheduleTaskDueToday(for: task, prefs: prefs, now: now)
        }
    }

    private static func rescheduleEvents(
        _ environment: AppEnvironment,
        spaceId: UUID,
        prefs: NotificationPrefs,
        now: Date
    ) async {
        guard prefs.eventSoon else { return }
        let repository = environment.repositories.events
        guard let events = try? await repository.events(spaceId: spaceId, from: now, to: nil) else { return }
        for event in events {
            _ = try? await environment.notifications.scheduleEventReminders(for: event, prefs: prefs, now: now)
            _ = try? await environment.notifications.scheduleEventDigest(for: event, prefs: prefs, now: now)
        }
    }

    private static func rescheduleCapsules(
        _ environment: AppEnvironment,
        spaceId: UUID,
        member: MemberDTO,
        prefs: NotificationPrefs,
        now: Date
    ) async {
        guard prefs.capsuleUpdates else { return }
        guard let capsules = try? await environment.repositories.capsules.capsules(spaceId: spaceId) else { return }
        for capsule in capsules where capsule.openedAt == nil {
            _ = try? await environment.notifications.scheduleCapsuleOpen(
                for: capsule,
                viewerMemberId: member.id,
                partnerName: environment.partnerName,
                prefs: prefs,
                now: now
            )
        }
    }
}
