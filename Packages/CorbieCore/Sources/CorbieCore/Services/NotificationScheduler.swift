import Foundation

public enum NotificationKind: String, Sendable, Equatable, CaseIterable {
    case eventReminder
    case taskDueToday
    case capsuleOpens
    case dateRadar
    case eventDigest

    public var prefix: String { "corbie." + rawValue + "." }

    public func isEnabled(in prefs: NotificationPrefs) -> Bool {
        switch self {
        case .eventReminder, .eventDigest:
            return prefs.eventSoon
        case .taskDueToday:
            return prefs.taskDueToday
        case .capsuleOpens:
            return prefs.capsuleUpdates
        case .dateRadar:
            return prefs.dateRadar
        }
    }
}

public enum EventDigestSlot: String, Sendable, Equatable, CaseIterable {
    case today
    case tomorrow
}

public enum NotificationIdentifier {
    public static func eventReminder(eventId: UUID, offset: ReminderOffset) -> String {
        NotificationKind.eventReminder.prefix + eventId.uuidString + "." + String(offset.days)
    }

    public static func taskDueToday(taskId: UUID) -> String {
        NotificationKind.taskDueToday.prefix + taskId.uuidString
    }

    public static func capsuleOpens(capsuleId: UUID) -> String {
        NotificationKind.capsuleOpens.prefix + capsuleId.uuidString
    }

    public static func dateRadar(autoDateId: String) -> String {
        NotificationKind.dateRadar.prefix + autoDateId
    }

    public static func eventDigest(eventId: UUID, slot: EventDigestSlot) -> String {
        NotificationKind.eventDigest.prefix + eventId.uuidString + "." + slot.rawValue
    }
}

public actor NotificationScheduler {
    public static let taskDueHour = 9
    public static let capsuleOpenHour = 9
    public static let eventDigestHour = 9
    public static let allDayReminderHour = 9
    public static let radarHour = 10
    public static let radarLeadDays = 14

    private let client: any NotificationCenterClient
    private let calendar: Calendar

    public init(client: any NotificationCenterClient, calendar: Calendar = .current) {
        self.client = client
        self.calendar = calendar
    }

    public func requestAuthorizationIfNeeded() async throws -> Bool {
        switch await client.authorizationStatus() {
        case .authorized, .provisional:
            return true
        case .denied:
            return false
        case .notDetermined:
            return try await client.requestAuthorization()
        }
    }

    public func registerCategories() async {
        await client.registerCategories(NotificationCategories.all)
    }

    public func pendingIdentifiers() async -> [String] {
        await client.pendingIdentifiers()
    }

    @discardableResult
    public func scheduleEventReminders(
        for event: EventDTO,
        prefs: NotificationPrefs,
        now: Date
    ) async throws -> [CorbieNotificationRequest] {
        await cancelEventReminders(eventId: event.id)
        guard NotificationKind.eventReminder.isEnabled(in: prefs), let startAt = event.startAt else { return [] }
        var scheduled: [CorbieNotificationRequest] = []
        for offset in Set(event.reminderOffsets).sorted(by: { $0.days > $1.days }) {
            guard let fireDate = reminderFireDate(start: startAt, isAllDay: event.isAllDay, offset: offset),
                  fireDate > now else { continue }
            let request = CorbieNotificationRequest(
                id: NotificationIdentifier.eventReminder(eventId: event.id, offset: offset),
                fireDate: fireDate,
                content: CorbieNotificationContent(
                    titleKey: NotificationStrings.eventReminderTitle,
                    bodyKey: NotificationStrings.eventReminderBody,
                    arguments: [event.title, String(offset.days)],
                    threadIdentifier: NotificationKind.eventReminder.rawValue,
                    userInfo: NotificationPayload.userInfo(
                        kind: .eventReminder,
                        route: .event(event.id),
                        objectId: event.id
                    )
                )
            )
            try await client.add(request)
            scheduled.append(request)
        }
        return scheduled
    }

    public func cancelEventReminders(eventId: UUID) async {
        await cancel(prefix: NotificationKind.eventReminder.prefix + eventId.uuidString)
    }

    @discardableResult
    public func scheduleTaskDueToday(
        for task: TaskDTO,
        prefs: NotificationPrefs,
        now: Date
    ) async throws -> CorbieNotificationRequest? {
        await cancelTaskDueToday(taskId: task.id)
        guard NotificationKind.taskDueToday.isEnabled(in: prefs),
              task.isDone == false,
              task.archivedAt == nil,
              let dueAt = task.dueAt,
              let fireDate = date(bySettingHour: NotificationScheduler.taskDueHour, on: dueAt),
              fireDate > now else { return nil }
        let request = CorbieNotificationRequest(
            id: NotificationIdentifier.taskDueToday(taskId: task.id),
            fireDate: fireDate,
            content: CorbieNotificationContent(
                titleKey: NotificationStrings.taskDueTodayTitle,
                bodyKey: NotificationStrings.taskDueTodayBody,
                arguments: [task.title],
                categoryIdentifier: NotificationCategories.task,
                threadIdentifier: NotificationKind.taskDueToday.rawValue,
                userInfo: NotificationPayload.userInfo(
                    kind: .taskDueToday,
                    route: .task(task.id),
                    objectId: task.id
                )
            )
        )
        try await client.add(request)
        return request
    }

    public func cancelTaskDueToday(taskId: UUID) async {
        await cancel(identifiers: [NotificationIdentifier.taskDueToday(taskId: taskId)])
    }

    @discardableResult
    public func scheduleCapsuleOpen(
        for capsule: CapsuleDTO,
        viewerMemberId: UUID?,
        partnerName: String?,
        prefs: NotificationPrefs,
        now: Date
    ) async throws -> CorbieNotificationRequest? {
        await cancelCapsuleOpen(capsuleId: capsule.id)
        guard NotificationKind.capsuleOpens.isEnabled(in: prefs),
              capsule.openedAt == nil,
              let opensAt = capsule.opensAt,
              let fireDate = date(bySettingHour: NotificationScheduler.capsuleOpenHour, on: opensAt),
              fireDate > now else { return nil }
        let isRecipient = viewerMemberId == nil || viewerMemberId == capsule.recipientMemberId
        let request = CorbieNotificationRequest(
            id: NotificationIdentifier.capsuleOpens(capsuleId: capsule.id),
            fireDate: fireDate,
            content: CorbieNotificationContent(
                titleKey: isRecipient ? NotificationStrings.capsuleReceivedTitle : NotificationStrings.capsuleSentTitle,
                bodyKey: isRecipient ? NotificationStrings.capsuleReceivedBody : NotificationStrings.capsuleSentBody,
                arguments: [partnerName ?? "", capsule.title],
                threadIdentifier: NotificationKind.capsuleOpens.rawValue,
                userInfo: NotificationPayload.userInfo(
                    kind: .capsuleOpens,
                    route: .capsule(capsule.id),
                    objectId: capsule.id
                )
            )
        )
        try await client.add(request)
        return request
    }

    public func cancelCapsuleOpen(capsuleId: UUID) async {
        await cancel(identifiers: [NotificationIdentifier.capsuleOpens(capsuleId: capsuleId)])
    }

    @discardableResult
    public func scheduleRadar(
        autoDateId: String,
        name: String?,
        targetDate: Date,
        ideasCount: Int,
        giftPicked: Bool,
        route: CorbieRoute,
        prefs: NotificationPrefs,
        now: Date
    ) async throws -> CorbieNotificationRequest? {
        await cancelRadar(autoDateId: autoDateId)
        guard NotificationKind.dateRadar.isEnabled(in: prefs),
              let leadDay = calendar.date(byAdding: .day, value: -NotificationScheduler.radarLeadDays, to: targetDate),
              let fireDate = date(bySettingHour: NotificationScheduler.radarHour, on: leadDay),
              fireDate > now else { return nil }
        let request = CorbieNotificationRequest(
            id: NotificationIdentifier.dateRadar(autoDateId: autoDateId),
            fireDate: fireDate,
            content: CorbieNotificationContent(
                titleKey: NotificationStrings.radarTitle,
                bodyKey: giftPicked ? NotificationStrings.radarBodyPicked : NotificationStrings.radarBodyMissing,
                arguments: [name ?? "", String(NotificationScheduler.radarLeadDays), String(ideasCount)],
                threadIdentifier: NotificationKind.dateRadar.rawValue,
                userInfo: NotificationPayload.userInfo(kind: .dateRadar, route: route)
            )
        )
        try await client.add(request)
        return request
    }

    public func cancelRadar(autoDateId: String) async {
        await cancel(identifiers: [NotificationIdentifier.dateRadar(autoDateId: autoDateId)])
    }

    @discardableResult
    public func scheduleEventDigest(
        for event: EventDTO,
        prefs: NotificationPrefs,
        now: Date
    ) async throws -> [CorbieNotificationRequest] {
        await cancelEventDigest(eventId: event.id)
        guard NotificationKind.eventDigest.isEnabled(in: prefs), let startAt = event.startAt else { return [] }
        var scheduled: [CorbieNotificationRequest] = []
        for slot in EventDigestSlot.allCases {
            guard let day = digestDay(for: slot, start: startAt),
                  let fireDate = date(bySettingHour: NotificationScheduler.eventDigestHour, on: day),
                  fireDate > now,
                  event.isAllDay || fireDate < startAt else { continue }
            let request = CorbieNotificationRequest(
                id: NotificationIdentifier.eventDigest(eventId: event.id, slot: slot),
                fireDate: fireDate,
                content: CorbieNotificationContent(
                    titleKey: slot == .today
                        ? NotificationStrings.eventTodayTitle
                        : NotificationStrings.eventTomorrowTitle,
                    bodyKey: slot == .today
                        ? NotificationStrings.eventTodayBody
                        : NotificationStrings.eventTomorrowBody,
                    arguments: [event.title],
                    threadIdentifier: NotificationKind.eventDigest.rawValue,
                    userInfo: NotificationPayload.userInfo(
                        kind: .eventDigest,
                        route: .event(event.id),
                        objectId: event.id
                    )
                )
            )
            try await client.add(request)
            scheduled.append(request)
        }
        return scheduled
    }

    public func cancelEventDigest(eventId: UUID) async {
        await cancel(prefix: NotificationKind.eventDigest.prefix + eventId.uuidString)
    }

    public func cancelAll(kind: NotificationKind) async {
        await cancel(prefix: kind.prefix)
    }

    public func cancelEverything() async {
        let pending = await client.pendingIdentifiers()
        let corbie = pending.filter { identifier in
            NotificationKind.allCases.contains { identifier.hasPrefix($0.prefix) }
        }
        guard corbie.isEmpty == false else { return }
        await client.removePending(identifiers: corbie)
    }

    private func cancel(prefix: String) async {
        let pending = await client.pendingIdentifiers()
        let matching = pending.filter { $0.hasPrefix(prefix) }
        guard matching.isEmpty == false else { return }
        await client.removePending(identifiers: matching)
    }

    private func cancel(identifiers: [String]) async {
        guard identifiers.isEmpty == false else { return }
        await client.removePending(identifiers: identifiers)
    }

    private func reminderFireDate(start: Date, isAllDay: Bool, offset: ReminderOffset) -> Date? {
        guard let shifted = calendar.date(byAdding: .day, value: -offset.days, to: start) else { return nil }
        guard isAllDay else { return shifted }
        return date(bySettingHour: NotificationScheduler.allDayReminderHour, on: shifted)
    }

    private func digestDay(for slot: EventDigestSlot, start: Date) -> Date? {
        switch slot {
        case .today:
            return start
        case .tomorrow:
            return calendar.date(byAdding: .day, value: -1, to: start)
        }
    }

    private func date(bySettingHour hour: Int, on day: Date) -> Date? {
        calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)
    }
}
