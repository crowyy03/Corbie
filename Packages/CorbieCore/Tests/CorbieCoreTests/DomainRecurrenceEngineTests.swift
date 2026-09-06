import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainRecurrenceEngineTests {
    private let utc = DomainClock.calendar()

    private func task(_ recurrence: Recurrence, dueAt: Date?) -> TaskDTO {
        TaskDTO(id: UUID(), title: "chore", dueAt: dueAt, recurrence: recurrence)
    }

    @Test func nonRepeatingTasksHaveNoNextOccurrence() {
        let completedAt = DomainClock.date("2026-09-05 12:00", in: utc)
        #expect(RecurrenceEngine.nextOccurrence(for: task(.none, dueAt: completedAt), completedAt: completedAt, calendar: utc) == nil)
        #expect(RecurrenceEngine.nextOccurrence(for: task(.weekdays([]), dueAt: completedAt), completedAt: completedAt, calendar: utc) == nil)
    }

    @Test func missingDueDateFallsBackToTheCompletionDate() {
        let completedAt = DomainClock.date("2026-09-05 12:00", in: utc)
        let next = RecurrenceEngine.nextOccurrence(for: task(.weekly, dueAt: nil), completedAt: completedAt, calendar: utc)
        #expect(next == DomainClock.date("2026-09-12 12:00", in: utc))
    }

    @Test func monthlyClampsToTheEndOfAShortMonth() {
        let due = DomainClock.date("2027-01-31 08:00", in: utc)
        let completedAt = DomainClock.date("2027-01-31 20:00", in: utc)
        let next = RecurrenceEngine.nextOccurrence(for: task(.monthly, dueAt: due), completedAt: completedAt, calendar: utc)
        #expect(next == DomainClock.date("2027-02-28 08:00", in: utc))
    }

    @Test func repeatedMonthlyClampingKeepsTheClampedDay() {
        let due = DomainClock.date("2027-01-31 08:00", in: utc)
        let completedAt = DomainClock.date("2027-01-31 20:00", in: utc)
        var dates: [Date] = []
        var cursor = due
        var completion = completedAt
        for _ in 0 ..< 3 {
            guard let next = RecurrenceEngine.nextOccurrence(
                recurrence: .monthly,
                dueAt: cursor,
                completedAt: completion,
                calendar: utc
            ) else { break }
            dates.append(next)
            cursor = next
            completion = next
        }
        #expect(dates.count == 3)
        #expect(dates[0] == DomainClock.date("2027-02-28 08:00", in: utc))
        #expect(dates[1] == DomainClock.date("2027-03-28 08:00", in: utc))
        #expect(dates[2] == DomainClock.date("2027-04-28 08:00", in: utc))
    }

    @Test func weekdaysWrapIntoTheFollowingWeek() {
        let wednesday = DomainClock.date("2026-09-09 09:00", in: utc)
        let next = RecurrenceEngine.nextOccurrence(
            for: task(.weekdays([2, 4]), dueAt: wednesday),
            completedAt: wednesday,
            calendar: utc
        )
        #expect(next == DomainClock.date("2026-09-14 09:00", in: utc))
        #expect(utc.component(.weekday, from: next ?? Date()) == 2)
    }

    @Test func weekdaysNeverReturnADateBeforeTheCompletion() {
        let overdue = DomainClock.date("2026-08-05 09:00", in: utc)
        let completedAt = DomainClock.date("2026-09-05 12:00", in: utc)
        let next = RecurrenceEngine.nextOccurrence(
            for: task(.weekdays([2, 4]), dueAt: overdue),
            completedAt: completedAt,
            calendar: utc
        )
        #expect(next == DomainClock.date("2026-09-07 09:00", in: utc))
    }

    @Test func dailyCatchesUpFromAnOverdueDueDate() {
        let overdue = DomainClock.date("2026-09-01 09:00", in: utc)
        let completedAt = DomainClock.date("2026-09-05 12:00", in: utc)
        let next = RecurrenceEngine.nextOccurrence(
            for: task(.daily, dueAt: overdue),
            completedAt: completedAt,
            calendar: utc
        )
        #expect(next == DomainClock.date("2026-09-06 09:00", in: utc))
    }

    @Test func dailyKeepsTheWallClockAcrossTheAmericanDaylightSavingEnd() {
        let newYork = DomainClock.calendar(locale: "en_US", timeZone: "America/New_York")
        let due = DomainClock.date("2026-10-31 09:00", in: newYork)
        let completedAt = DomainClock.date("2026-10-31 12:00", in: newYork)
        let next = RecurrenceEngine.nextOccurrence(for: task(.daily, dueAt: due), completedAt: completedAt, calendar: newYork)
        #expect(DomainClock.text(next ?? Date(), in: newYork) == "2026-11-01 09:00")
        #expect((next?.timeIntervalSince(due) ?? 0) == 25 * 3600)
    }

    @Test func weeklyKeepsTheWallClockAcrossTheEuropeanDaylightSavingEnd() {
        let berlin = DomainClock.calendar(locale: "de_DE", timeZone: "Europe/Berlin")
        let due = DomainClock.date("2026-10-21 08:00", in: berlin)
        let completedAt = DomainClock.date("2026-10-21 19:00", in: berlin)
        let next = RecurrenceEngine.nextOccurrence(for: task(.weekly, dueAt: due), completedAt: completedAt, calendar: berlin)
        #expect(DomainClock.text(next ?? Date(), in: berlin) == "2026-10-28 08:00")
    }

    @Test func americanAndGermanCalendarsAgreeOnTheSameSchedule() {
        let american = DomainClock.calendar(locale: "en_US", timeZone: "Europe/Berlin")
        let german = DomainClock.calendar(locale: "de_DE", timeZone: "Europe/Berlin")
        #expect(american.firstWeekday != german.firstWeekday)
        let due = DomainClock.date("2026-09-09 09:00", in: american)
        let completedAt = DomainClock.date("2026-09-09 10:00", in: american)
        for recurrence in [Recurrence.daily, .weekly, .monthly, .weekdays([2, 4])] {
            let left = RecurrenceEngine.nextOccurrence(
                for: task(recurrence, dueAt: due),
                completedAt: completedAt,
                calendar: american
            )
            let right = RecurrenceEngine.nextOccurrence(
                for: task(recurrence, dueAt: due),
                completedAt: completedAt,
                calendar: german
            )
            #expect(left == right)
        }
    }

    @Test func aFutureDueDateSchedulesOnePeriodAfterIt() {
        let due = DomainClock.date("2026-09-20 09:00", in: utc)
        let completedAt = DomainClock.date("2026-09-05 12:00", in: utc)
        let next = RecurrenceEngine.nextOccurrence(for: task(.weekly, dueAt: due), completedAt: completedAt, calendar: utc)
        #expect(next == DomainClock.date("2026-09-27 09:00", in: utc))
    }
}
