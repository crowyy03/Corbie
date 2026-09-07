import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainNotificationSchedulerTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "Europe/Berlin")

    private func scheduler(_ center: FakeNotificationCenter) -> NotificationScheduler {
        NotificationScheduler(client: center, calendar: calendar)
    }

    @Test func eventRemindersUseStableIdentifiersPerOffset() async throws {
        let center = FakeNotificationCenter()
        let event = EventDTO(
            id: UUID(),
            title: "Dinner",
            startAt: DomainClock.date("2026-10-01 19:00", in: calendar),
            reminderOffsets: [.dayBefore, .threeDaysBefore, .twoWeeksBefore]
        )
        let scheduled = try await scheduler(center).scheduleEventReminders(
            for: event,
            prefs: .allEnabled,
            now: DomainClock.date("2026-09-05 12:00", in: calendar)
        )
        #expect(scheduled.count == 3)
        let identifiers = await center.pendingIdentifiers()
        #expect(identifiers.contains(NotificationIdentifier.eventReminder(eventId: event.id, offset: .dayBefore)))
        #expect(identifiers.contains(NotificationIdentifier.eventReminder(eventId: event.id, offset: .threeDaysBefore)))
        #expect(identifiers.contains(NotificationIdentifier.eventReminder(eventId: event.id, offset: .twoWeeksBefore)))
        let dayBefore = await center.request(
            id: NotificationIdentifier.eventReminder(eventId: event.id, offset: .dayBefore)
        )
        #expect(DomainClock.text(dayBefore?.fireDate ?? Date(), in: calendar) == "2026-09-30 19:00")
        #expect(dayBefore?.content.userInfo[NotificationPayload.routeKey] == CorbieRoute.event(event.id).urlString)
    }

    @Test func allDayEventRemindersFireAtNineLocal() async throws {
        let center = FakeNotificationCenter()
        let event = EventDTO(
            id: UUID(),
            title: "Lisbon",
            startAt: DomainClock.date("2026-10-01", in: calendar),
            isAllDay: true,
            reminderOffsets: [.threeDaysBefore]
        )
        _ = try await scheduler(center).scheduleEventReminders(
            for: event,
            prefs: .allEnabled,
            now: DomainClock.date("2026-09-05 12:00", in: calendar)
        )
        let request = await center.requests.first
        #expect(DomainClock.text(request?.fireDate ?? Date(), in: calendar) == "2026-09-28 09:00")
    }

    @Test func remindersInThePastAreSkipped() async throws {
        let center = FakeNotificationCenter()
        let event = EventDTO(
            id: UUID(),
            title: "Dinner",
            startAt: DomainClock.date("2026-09-06 19:00", in: calendar),
            reminderOffsets: [.dayBefore, .twoWeeksBefore]
        )
        let scheduled = try await scheduler(center).scheduleEventReminders(
            for: event,
            prefs: .allEnabled,
            now: DomainClock.date("2026-09-05 12:00", in: calendar)
        )
        #expect(scheduled.count == 1)
        #expect(scheduled[0].id.hasSuffix(".1"))
    }

    @Test func schedulingTwiceReplacesTheEarlierRequests() async throws {
        let center = FakeNotificationCenter()
        let engine = scheduler(center)
        var event = EventDTO(
            id: UUID(),
            title: "Dinner",
            startAt: DomainClock.date("2026-10-01 19:00", in: calendar),
            reminderOffsets: [.dayBefore, .threeDaysBefore]
        )
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        _ = try await engine.scheduleEventReminders(for: event, prefs: .allEnabled, now: now)
        event.reminderOffsets = [.dayBefore]
        _ = try await engine.scheduleEventReminders(for: event, prefs: .allEnabled, now: now)
        let identifiers = await center.pendingIdentifiers()
        #expect(identifiers.count == 1)
        #expect(identifiers[0] == NotificationIdentifier.eventReminder(eventId: event.id, offset: .dayBefore))
    }

    @Test func eventRemindersRespectThePreference() async throws {
        let center = FakeNotificationCenter()
        var prefs = NotificationPrefs.allEnabled
        prefs.eventSoon = false
        let event = EventDTO(
            id: UUID(),
            title: "Dinner",
            startAt: DomainClock.date("2026-10-01 19:00", in: calendar),
            reminderOffsets: [.dayBefore]
        )
        let scheduled = try await scheduler(center).scheduleEventReminders(
            for: event,
            prefs: prefs,
            now: DomainClock.date("2026-09-05 12:00", in: calendar)
        )
        #expect(scheduled.isEmpty)
        #expect(await center.requests.isEmpty)
    }

    @Test func taskDueTodayFiresAtNineLocalOnTheDueDay() async throws {
        let center = FakeNotificationCenter()
        let task = TaskDTO(
            id: UUID(),
            title: "Book the vet",
            dueAt: DomainClock.date("2026-09-10 16:30", in: calendar)
        )
        let request = try await scheduler(center).scheduleTaskDueToday(
            for: task,
            prefs: .allEnabled,
            now: DomainClock.date("2026-09-05 12:00", in: calendar)
        )
        #expect(request?.id == NotificationIdentifier.taskDueToday(taskId: task.id))
        #expect(DomainClock.text(request?.fireDate ?? Date(), in: calendar) == "2026-09-10 09:00")
        #expect(request?.content.categoryIdentifier == NotificationCategories.task)
    }

    @Test func doneAndArchivedTasksAreNotScheduled() async throws {
        let center = FakeNotificationCenter()
        let engine = scheduler(center)
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let due = DomainClock.date("2026-09-10 16:30", in: calendar)
        let done = TaskDTO(id: UUID(), title: "done", dueAt: due, isDone: true)
        let archived = TaskDTO(id: UUID(), title: "archived", dueAt: due, archivedAt: now)
        let undated = TaskDTO(id: UUID(), title: "undated")
        #expect(try await engine.scheduleTaskDueToday(for: done, prefs: .allEnabled, now: now) == nil)
        #expect(try await engine.scheduleTaskDueToday(for: archived, prefs: .allEnabled, now: now) == nil)
        #expect(try await engine.scheduleTaskDueToday(for: undated, prefs: .allEnabled, now: now) == nil)
    }

    @Test func capsuleOpensAtNineLocalAndUsesTheRecipientCopy() async throws {
        let center = FakeNotificationCenter()
        let recipient = UUID()
        let author = UUID()
        let capsule = CapsuleDTO(
            id: UUID(),
            authorMemberId: author,
            recipientMemberId: recipient,
            title: "First year",
            opensAt: DomainClock.date("2027-02-14 00:00", in: calendar)
        )
        let engine = scheduler(center)
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let received = try await engine.scheduleCapsuleOpen(
            for: capsule,
            viewerMemberId: recipient,
            partnerName: "Sofia",
            prefs: .allEnabled,
            now: now
        )
        #expect(received?.id == NotificationIdentifier.capsuleOpens(capsuleId: capsule.id))
        #expect(DomainClock.text(received?.fireDate ?? Date(), in: calendar) == "2027-02-14 09:00")
        #expect(received?.content.bodyKey == NotificationStrings.capsuleReceivedBody)
        let sent = try await engine.scheduleCapsuleOpen(
            for: capsule,
            viewerMemberId: author,
            partnerName: "Sofia",
            prefs: .allEnabled,
            now: now
        )
        #expect(sent?.content.bodyKey == NotificationStrings.capsuleSentBody)
        #expect(await center.pendingIdentifiers().count == 1)
    }

    @Test func radarFiresFourteenDaysAheadAtTenLocal() async throws {
        let center = FakeNotificationCenter()
        let target = DomainClock.date("2026-10-12", in: calendar)
        let request = try await scheduler(center).scheduleRadar(
            autoDateId: "auto.personBirthday.anna",
            name: "Anna",
            targetDate: target,
            ideasCount: 3,
            giftPicked: false,
            route: .people,
            prefs: .allEnabled,
            now: DomainClock.date("2026-09-05 12:00", in: calendar)
        )
        #expect(request?.id == NotificationIdentifier.dateRadar(autoDateId: "auto.personBirthday.anna"))
        #expect(DomainClock.text(request?.fireDate ?? Date(), in: calendar) == "2026-09-28 10:00")
        #expect(request?.content.bodyKey == NotificationStrings.radarBodyMissing)
        #expect(request?.content.arguments == ["Anna", "14", "3"])
    }

    @Test func radarInsideTheLeadWindowIsNotScheduled() async throws {
        let center = FakeNotificationCenter()
        let request = try await scheduler(center).scheduleRadar(
            autoDateId: "auto.personBirthday.anna",
            name: "Anna",
            targetDate: DomainClock.date("2026-09-10", in: calendar),
            ideasCount: 0,
            giftPicked: true,
            route: .people,
            prefs: .allEnabled,
            now: DomainClock.date("2026-09-05 12:00", in: calendar)
        )
        #expect(request == nil)
        #expect(await center.requests.isEmpty)
    }

    @Test func eventDigestCoversTodayAndTomorrow() async throws {
        let center = FakeNotificationCenter()
        let event = EventDTO(
            id: UUID(),
            title: "Dinner",
            startAt: DomainClock.date("2026-09-10 19:00", in: calendar)
        )
        let scheduled = try await scheduler(center).scheduleEventDigest(
            for: event,
            prefs: .allEnabled,
            now: DomainClock.date("2026-09-05 12:00", in: calendar)
        )
        #expect(scheduled.count == 2)
        let today = await center.request(id: NotificationIdentifier.eventDigest(eventId: event.id, slot: .today))
        let tomorrow = await center.request(id: NotificationIdentifier.eventDigest(eventId: event.id, slot: .tomorrow))
        #expect(DomainClock.text(today?.fireDate ?? Date(), in: calendar) == "2026-09-10 09:00")
        #expect(DomainClock.text(tomorrow?.fireDate ?? Date(), in: calendar) == "2026-09-09 09:00")
        #expect(today?.content.titleKey == NotificationStrings.eventTodayTitle)
        #expect(tomorrow?.content.titleKey == NotificationStrings.eventTomorrowTitle)
    }

    @Test func eventDigestSkipsTheSameDayWhenTheEventStartsBeforeNine() async throws {
        let center = FakeNotificationCenter()
        let event = EventDTO(
            id: UUID(),
            title: "Early flight",
            startAt: DomainClock.date("2026-09-10 07:00", in: calendar)
        )
        let scheduled = try await scheduler(center).scheduleEventDigest(
            for: event,
            prefs: .allEnabled,
            now: DomainClock.date("2026-09-05 12:00", in: calendar)
        )
        #expect(scheduled.count == 1)
        #expect(scheduled[0].id == NotificationIdentifier.eventDigest(eventId: event.id, slot: .tomorrow))
    }

    @Test func cancellingOneKindLeavesTheOthersInPlace() async throws {
        let center = FakeNotificationCenter()
        let engine = scheduler(center)
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let event = EventDTO(
            id: UUID(),
            title: "Dinner",
            startAt: DomainClock.date("2026-10-01 19:00", in: calendar),
            reminderOffsets: [.dayBefore]
        )
        let task = TaskDTO(id: UUID(), title: "Book the vet", dueAt: DomainClock.date("2026-09-10 16:30", in: calendar))
        _ = try await engine.scheduleEventReminders(for: event, prefs: .allEnabled, now: now)
        _ = try await engine.scheduleTaskDueToday(for: task, prefs: .allEnabled, now: now)
        await engine.cancelAll(kind: .eventReminder)
        let identifiers = await center.pendingIdentifiers()
        #expect(identifiers == [NotificationIdentifier.taskDueToday(taskId: task.id)])
    }

    @Test func authorizationIsOnlyRequestedWhenUndecided() async throws {
        let undecided = FakeNotificationCenter(status: .notDetermined)
        #expect(try await scheduler(undecided).requestAuthorizationIfNeeded())
        #expect(await undecided.authorizationCalls == 1)
        #expect(try await scheduler(undecided).requestAuthorizationIfNeeded())
        #expect(await undecided.authorizationCalls == 1)

        let denied = FakeNotificationCenter(status: .denied)
        #expect(try await scheduler(denied).requestAuthorizationIfNeeded() == false)
        #expect(await denied.authorizationCalls == 0)

        let refusing = FakeNotificationCenter(status: .notDetermined, grants: false)
        #expect(try await scheduler(refusing).requestAuthorizationIfNeeded() == false)
        #expect(await refusing.authorizationCalls == 1)
    }

    @Test func categoriesCarryTheTaskAndVoteActions() async {
        let center = FakeNotificationCenter()
        await scheduler(center).registerCategories()
        let registered = await center.categories
        #expect(registered.count == 2)
        let task = registered.first { $0.identifier == NotificationCategories.task }
        #expect(task?.actions.map(\.identifier) == [
            NotificationCategories.Action.takeTask,
            NotificationCategories.Action.completeTask
        ])
        let vote = registered.first { $0.identifier == NotificationCategories.vote }
        #expect(vote?.actions.map(\.identifier) == [NotificationCategories.Action.castVote])
    }

    @Test func everyKindMapsToAPreference() {
        var prefs = NotificationPrefs.allEnabled
        prefs.eventSoon = false
        prefs.taskDueToday = false
        prefs.capsuleUpdates = false
        prefs.dateRadar = false
        prefs.weeklyRecap = false
        prefs.questionOfTheDay = false
        prefs.choreSplitReady = false
        for kind in NotificationKind.allCases {
            #expect(kind.isEnabled(in: .allEnabled))
            #expect(kind.isEnabled(in: prefs) == false)
            #expect(kind.prefix.hasPrefix("corbie."))
        }
    }
}
