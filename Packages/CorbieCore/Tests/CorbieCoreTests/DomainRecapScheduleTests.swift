import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainRecapScheduleTests {
    private func mondayFirst() -> Calendar {
        var calendar = DomainClock.calendar(locale: "en_GB", timeZone: "UTC")
        calendar.firstWeekday = 2
        return calendar
    }

    private func sundayFirst() -> Calendar {
        var calendar = DomainClock.calendar(locale: "en_US", timeZone: "UTC")
        calendar.firstWeekday = 1
        return calendar
    }

    @Test func sundayKeepsWeekdayIndexOneWhateverTheWeekStartsOn() {
        #expect(RecapSchedule.sundayWeekday(in: mondayFirst()) == 1)
        #expect(RecapSchedule.sundayWeekday(in: sundayFirst()) == 1)
        var tokyo = DomainClock.calendar(locale: "ja_JP", timeZone: "Asia/Tokyo")
        tokyo.firstWeekday = 1
        #expect(RecapSchedule.sundayWeekday(in: tokyo) == 1)
    }

    @Test func theWeekRunsMondayToSundayForBothWeekStarts() {
        for calendar in [mondayFirst(), sundayFirst()] {
            let sunday = DomainClock.date("2026-09-06 19:30", in: calendar)
            let week = RecapSchedule.week(closing: sunday, calendar: calendar)
            #expect(DomainClock.text(week.start, in: calendar) == "2026-08-31 00:00")
            #expect(DomainClock.text(week.end, in: calendar) == "2026-09-07 00:00")
            #expect(week.contains(DomainClock.date("2026-09-06 23:59", in: calendar)))
            #expect(week.contains(DomainClock.date("2026-08-30 23:59", in: calendar)) == false)
        }
    }

    @Test func mondayMorningStillClosesTheWeekThatJustEnded() {
        let calendar = mondayFirst()
        let monday = DomainClock.date("2026-09-07 08:00", in: calendar)
        let week = RecapSchedule.week(closing: monday, calendar: calendar)
        #expect(DomainClock.text(week.start, in: calendar) == "2026-08-31 00:00")
        #expect(DomainClock.text(week.end, in: calendar) == "2026-09-07 00:00")
    }

    @Test func theNextNotificationLandsOnTheComingSundayEvening() {
        let calendar = mondayFirst()
        let wednesday = DomainClock.date("2026-09-02 10:00", in: calendar)
        let fireDate = RecapSchedule.nextNotificationDate(after: wednesday, calendar: calendar)
        #expect(fireDate.map { DomainClock.text($0, in: calendar) } == "2026-09-06 19:00")
        let sundayEvening = DomainClock.date("2026-09-06 19:30", in: calendar)
        let next = RecapSchedule.nextNotificationDate(after: sundayEvening, calendar: calendar)
        #expect(next.map { DomainClock.text($0, in: calendar) } == "2026-09-13 19:00")
    }

    @Test func theCardIsVisibleFromSundayEveningToMondayMorning() {
        let calendar = mondayFirst()
        let visible = [
            "2026-09-06 19:00",
            "2026-09-06 23:59",
            "2026-09-07 08:59"
        ]
        for value in visible {
            let now = DomainClock.date(value, in: calendar)
            #expect(RecapSchedule.isCardVisible(now: now, lastSeenAt: nil, calendar: calendar))
        }
        let hidden = [
            "2026-09-06 18:59",
            "2026-09-07 09:00",
            "2026-09-08 20:00"
        ]
        for value in hidden {
            let now = DomainClock.date(value, in: calendar)
            #expect(RecapSchedule.isCardVisible(now: now, lastSeenAt: nil, calendar: calendar) == false)
        }
    }

    @Test func seeingTheCardInsideTheWindowHidesItUntilNextWeek() {
        let calendar = mondayFirst()
        let now = DomainClock.date("2026-09-06 21:00", in: calendar)
        let seen = DomainClock.date("2026-09-06 20:00", in: calendar)
        #expect(RecapSchedule.isCardVisible(now: now, lastSeenAt: seen, calendar: calendar) == false)
        let lastWeek = DomainClock.date("2026-08-30 20:00", in: calendar)
        #expect(RecapSchedule.isCardVisible(now: now, lastSeenAt: lastWeek, calendar: calendar))
    }
}
