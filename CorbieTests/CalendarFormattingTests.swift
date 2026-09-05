import CorbieCore
import XCTest
@testable import Corbie

final class CalendarFormattingTests: XCTestCase {
    private let calendar = CalendarTestSupport.calendar("en_US")

    private var formatting: CalendarFormatting {
        CalendarFormatting(locale: Locale(identifier: "en_US"), calendar: calendar)
    }

    func testAnniversaryTitleUsesThePluralVariation() {
        let single = CalendarTestSupport.autoDate(
            kind: .anniversary,
            date: CalendarTestSupport.date(calendar, 2026, 9, 21),
            years: 1
        )
        let many = CalendarTestSupport.autoDate(
            kind: .anniversary,
            date: CalendarTestSupport.date(calendar, 2027, 9, 21),
            years: 2
        )

        XCTAssertEqual(formatting.title(for: single), "1 year together")
        XCTAssertEqual(formatting.title(for: many), "2 years together")
    }

    func testBirthdayTitleUsesTheName() {
        let named = CalendarTestSupport.autoDate(
            kind: .personBirthday,
            date: CalendarTestSupport.date(calendar, 2026, 9, 4),
            name: "Anna",
            personId: UUID()
        )
        let unnamed = CalendarTestSupport.autoDate(
            kind: .memberBirthday,
            date: CalendarTestSupport.date(calendar, 2026, 9, 4),
            ownerMemberId: UUID()
        )

        XCTAssertTrue(formatting.title(for: named).contains("Anna"))
        XCTAssertEqual(formatting.title(for: unnamed), "Birthday")
    }

    func testAllDayEntryReportsNoTimeRange() throws {
        let event = CalendarTestSupport.event(
            calendar,
            title: "Anniversary",
            start: CalendarTestSupport.date(calendar, 2026, 9, 21),
            end: CalendarTestSupport.date(calendar, 2026, 9, 21, 23, 59),
            isAllDay: true
        )
        let entry = try XCTUnwrap(CalendarEntry(event: event, calendar: calendar))

        XCTAssertEqual(formatting.schedule(for: entry), "All day")
    }

    func testTimedEntryReportsBothEnds() throws {
        let event = CalendarTestSupport.event(
            calendar,
            title: "Dentist",
            start: CalendarTestSupport.date(calendar, 2026, 9, 4, 9),
            end: CalendarTestSupport.date(calendar, 2026, 9, 4, 10)
        )
        let entry = try XCTUnwrap(CalendarEntry(event: event, calendar: calendar))

        let schedule = formatting.schedule(for: entry)

        XCTAssertTrue(schedule.contains(" - "))
        XCTAssertFalse(schedule.contains("%"))
    }

    func testDayNumberIsTheDayOfMonth() {
        XCTAssertEqual(formatting.dayNumber(CalendarTestSupport.date(calendar, 2026, 9, 4)), "4")
    }
}
