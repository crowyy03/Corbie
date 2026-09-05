import Foundation
import Testing
@testable import CorbieCore

@Suite struct RecurrenceTests {
    private func date(_ iso: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return try #require(formatter.date(from: iso))
    }

    @Test func rawValuesRoundTrip() {
        let cases: [Recurrence] = [.none, .daily, .weekly, .monthly, .weekdays([2, 4, 6])]
        for value in cases {
            #expect(Recurrence(rawValue: value.rawValue) == value)
        }
        #expect(Recurrence.weekdays([6, 2, 2, 4]).rawValue == "weekdays:2,4,6")
        #expect(Recurrence(rawValue: "nonsense") == nil)
        #expect(Recurrence(rawValue: "weekdays:9,3") == .weekdays([3]))
    }

    @Test func nextDateFollowsTheSchedule() throws {
        let start = try date("2026-09-05T09:00:00Z")
        #expect(Recurrence.none.nextDate(after: start) == nil)
        #expect(try Recurrence.daily.nextDate(after: start) == date("2026-09-06T09:00:00Z"))
        #expect(try Recurrence.weekly.nextDate(after: start) == date("2026-09-12T09:00:00Z"))
        #expect(try Recurrence.monthly.nextDate(after: start) == date("2026-10-05T09:00:00Z"))
    }

    @Test func monthlyClampsToTheEndOfAShortMonth() throws {
        let endOfJanuary = try date("2027-01-31T08:00:00Z")
        #expect(try Recurrence.monthly.nextDate(after: endOfJanuary) == date("2027-02-28T08:00:00Z"))
    }

    @Test func weekdaysPicksTheNextSelectedDay() throws {
        let saturday = try date("2026-09-05T09:00:00Z")
        let weekdays = Recurrence.weekdays([2, 4])
        #expect(try weekdays.nextDate(after: saturday) == date("2026-09-07T09:00:00Z"))
        let monday = try date("2026-09-07T09:00:00Z")
        #expect(try weekdays.nextDate(after: monday) == date("2026-09-09T09:00:00Z"))
    }

    @Test func emptyWeekdaysNeverRepeat() throws {
        let start = try date("2026-09-05T09:00:00Z")
        let empty = Recurrence.weekdays([])
        #expect(empty.repeats == false)
        #expect(empty.nextDate(after: start) == nil)
    }
}
