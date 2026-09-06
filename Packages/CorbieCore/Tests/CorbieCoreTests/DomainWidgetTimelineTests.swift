import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainWidgetTimelineTests {
    @Test func theNextEntryIsTomorrowAtMidnight() {
        let calendar = DomainClock.calendar(timeZone: "UTC")
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let midnight = WidgetTimelineDates.nextMidnight(after: now, calendar: calendar)
        #expect(DomainClock.text(midnight, in: calendar) == "2026-09-06 00:00")
    }

    @Test func midnightItselfMovesOnToTheNextDay() {
        let calendar = DomainClock.calendar(timeZone: "UTC")
        let now = DomainClock.date("2026-09-05 00:00", in: calendar)
        let midnight = WidgetTimelineDates.nextMidnight(after: now, calendar: calendar)
        #expect(DomainClock.text(midnight, in: calendar) == "2026-09-06 00:00")
    }

    @Test func aShortSpringForwardDayStillEndsAtMidnight() {
        let calendar = DomainClock.calendar(timeZone: "America/New_York")
        let now = DomainClock.date("2026-03-08 12:00", in: calendar)
        let midnight = WidgetTimelineDates.nextMidnight(after: now, calendar: calendar)
        #expect(DomainClock.text(midnight, in: calendar) == "2026-03-09 00:00")
        #expect(midnight.timeIntervalSince(now) == 12 * 60 * 60)
    }

    @Test func theEveningBeforeASpringForwardCountsTwentyThreeHours() {
        let calendar = DomainClock.calendar(timeZone: "America/New_York")
        let now = DomainClock.date("2026-03-07 12:00", in: calendar)
        let midnight = WidgetTimelineDates.nextMidnight(after: now, calendar: calendar)
        #expect(DomainClock.text(midnight, in: calendar) == "2026-03-08 00:00")
        #expect(midnight.timeIntervalSince(now) == 12 * 60 * 60)
        let dayAfter = WidgetTimelineDates.nextMidnight(after: midnight, calendar: calendar)
        #expect(dayAfter.timeIntervalSince(midnight) == 23 * 60 * 60)
    }

    @Test func aLongFallBackDayCountsTwentyFiveHours() {
        let calendar = DomainClock.calendar(timeZone: "America/New_York")
        let now = DomainClock.date("2026-11-01 00:00", in: calendar)
        let midnight = WidgetTimelineDates.nextMidnight(after: now, calendar: calendar)
        #expect(DomainClock.text(midnight, in: calendar) == "2026-11-02 00:00")
        #expect(midnight.timeIntervalSince(now) == 25 * 60 * 60)
    }

    @Test func aDayThatHasNoMidnightStartsAnHourLate() {
        let calendar = DomainClock.calendar(timeZone: "America/Santiago")
        let now = DomainClock.date("2026-09-05 22:00", in: calendar)
        let midnight = WidgetTimelineDates.nextMidnight(after: now, calendar: calendar)
        #expect(DomainClock.text(midnight, in: calendar) == "2026-09-06 01:00")
        #expect(midnight.timeIntervalSince(now) == 2 * 60 * 60)
    }
}
