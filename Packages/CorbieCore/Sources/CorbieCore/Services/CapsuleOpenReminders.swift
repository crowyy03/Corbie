import Foundation
import os

public actor CapsuleOpenReminders {
    static let entities: Set<String> = [CapsuleItem.entityName, CapsuleOpen.entityName]

    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "reminders")

    private let capsules: any CapsuleRepository
    private let scheduler: NotificationScheduler
    private let now: @Sendable () -> Date

    private var queue: Task<Void, Never>?

    public init(
        capsules: any CapsuleRepository,
        scheduler: NotificationScheduler,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.capsules = capsules
        self.scheduler = scheduler
        self.now = now
    }

    public static func isTriggered(by records: [RemoteChangeRecord]) -> Bool {
        records.contains { record in
            guard record.isFromAnotherDevice, let entityName = record.entityName else { return false }
            return entities.contains(entityName)
        }
    }

    public func replan(for audience: RemoteChangeNotifier.Audience) async {
        let previous = queue
        let work = Task {
            await previous?.value
            await self.plan(for: audience)
        }
        queue = work
        await work.value
    }

    private func plan(for audience: RemoteChangeNotifier.Audience) async {
        let letters: [CapsuleDTO]
        do {
            letters = try await capsules.capsules(spaceId: audience.spaceId)
        } catch {
            CapsuleOpenReminders.log.error("letters unreadable: \(error.localizedDescription, privacy: .public)")
            return
        }
        do {
            try await scheduler.rescheduleCapsuleOpens(
                for: letters,
                viewerMemberId: audience.memberId,
                partnerName: audience.partnerName,
                prefs: audience.prefs,
                now: now()
            )
        } catch {
            CapsuleOpenReminders.log.error("letter alerts not scheduled: \(error.localizedDescription, privacy: .public)")
        }
    }
}
