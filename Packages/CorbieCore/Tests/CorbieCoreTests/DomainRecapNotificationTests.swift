import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainRecapNotificationTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "UTC")

    private var week: RecapWeek {
        RecapSchedule.week(closing: DomainClock.date("2026-09-06 19:00", in: calendar), calendar: calendar)
    }

    private func summary(
        tasks: (Int, Int) = (12, 7),
        comingUp: Int = 0,
        memberCount: Int = 2
    ) -> RecapSummary {
        let names = ["Ilya", "Sofia"]
        let tallies = (0..<memberCount).map { index in
            RecapMemberTally(
                memberId: UUID(),
                name: names[index],
                colorKey: "ice",
                tasksDone: index == 0 ? tasks.0 : tasks.1,
                wishesAdded: 0
            )
        }
        let dates = (0..<comingUp).map { index in
            RecapUpcoming(
                id: "event." + String(index),
                kind: .event,
                name: "Dinner",
                date: week.end,
                eventId: UUID()
            )
        }
        return RecapSummary(week: week, members: tallies, comingUp: dates, daysTogether: 1255)
    }

    @Test func theRecapIsScheduledForTheComingSundayEvening() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(client: center, calendar: calendar)
        let now = DomainClock.date("2026-09-02 10:00", in: calendar)
        let request = try await scheduler.scheduleWeeklyRecap(summary(), prefs: .allEnabled, now: now)
        let scheduled = try #require(request)
        #expect(scheduled.id == NotificationIdentifier.weeklyRecap)
        #expect(DomainClock.text(scheduled.fireDate, in: calendar) == "2026-09-06 19:00")
        #expect(scheduled.content.titleKey == NotificationStrings.recapTitle)
        #expect(scheduled.content.bodyKey == NotificationStrings.recapBody)
        #expect(scheduled.content.arguments == ["Ilya", "12", "Sofia", "7", "0"])
        #expect(await center.pendingIdentifiers() == [NotificationIdentifier.weeklyRecap])
    }

    @Test func datesNextWeekSwitchTheBody() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(client: center, calendar: calendar)
        let now = DomainClock.date("2026-09-02 10:00", in: calendar)
        let request = try await scheduler.scheduleWeeklyRecap(
            summary(comingUp: 3),
            prefs: .allEnabled,
            now: now
        )
        #expect(request?.content.bodyKey == NotificationStrings.recapBodyDates)
        #expect(request?.content.arguments.last == "3")
    }

    @Test func aQuietWeekSchedulesNothing() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(client: center, calendar: calendar)
        let now = DomainClock.date("2026-09-02 10:00", in: calendar)
        let request = try await scheduler.scheduleWeeklyRecap(
            summary(tasks: (0, 0)),
            prefs: .allEnabled,
            now: now
        )
        #expect(request == nil)
        #expect(await center.pendingIdentifiers().isEmpty)
    }

    @Test func aSoloSpaceSchedulesNothing() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(client: center, calendar: calendar)
        let now = DomainClock.date("2026-09-02 10:00", in: calendar)
        let request = try await scheduler.scheduleWeeklyRecap(
            summary(memberCount: 1),
            prefs: .allEnabled,
            now: now
        )
        #expect(request == nil)
    }

    @Test func theTenthToggleTurnsItOff() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(client: center, calendar: calendar)
        let now = DomainClock.date("2026-09-02 10:00", in: calendar)
        var prefs = NotificationPrefs.allEnabled
        prefs.weeklyRecap = false
        #expect(try await scheduler.scheduleWeeklyRecap(summary(), prefs: prefs, now: now) == nil)
    }

    @Test func reschedulingReplacesThePendingRequest() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(client: center, calendar: calendar)
        _ = try await scheduler.scheduleWeeklyRecap(
            summary(),
            prefs: .allEnabled,
            now: DomainClock.date("2026-09-02 10:00", in: calendar)
        )
        _ = try await scheduler.scheduleWeeklyRecap(
            summary(tasks: (1, 1)),
            prefs: .allEnabled,
            now: DomainClock.date("2026-09-04 10:00", in: calendar)
        )
        #expect(await center.pendingIdentifiers().count == 1)
        #expect(await center.request(id: NotificationIdentifier.weeklyRecap)?.content.arguments[1] == "1")
        await scheduler.cancelWeeklyRecap()
        #expect(await center.pendingIdentifiers().isEmpty)
    }

    @Test func aPrefsRoundTripKeepsTheOlderNineToggles() throws {
        let stored = """
        {"taskAssigned":false,"taskTakenOrHandedBack":true,"taskDueToday":false,"eventSoon":true,\
        "dateRadar":false,"partnerAddedWish":true,"goalUpdates":false,"capsuleUpdates":true,"voteUpdates":false}
        """
        let prefs = try #require(JSONValue.decode(NotificationPrefs.self, from: Data(stored.utf8)))
        #expect(prefs.taskAssigned == false)
        #expect(prefs.dateRadar == false)
        #expect(prefs.voteUpdates == false)
        #expect(prefs.weeklyRecap)
    }
}
