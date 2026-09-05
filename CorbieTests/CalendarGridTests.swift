import CorbieCore
import XCTest
@testable import Corbie

final class CalendarGridTests: XCTestCase {
    func testFirstWeekdayFollowsTheLocale() {
        let american = CalendarTestSupport.calendar("en_US")
        let german = CalendarTestSupport.calendar("de_DE")
        XCTAssertEqual(american.firstWeekday, 1)
        XCTAssertEqual(german.firstWeekday, 2)
    }

    func testGridStartsOnTheLocaleFirstWeekday() {
        let american = CalendarTestSupport.calendar("en_US")
        let german = CalendarTestSupport.calendar("de_DE")
        let september = CalendarTestSupport.date(american, 2026, 9, 1)

        let americanGrid = CalendarGrid(month: september, calendar: american)
        let germanGrid = CalendarGrid(month: CalendarTestSupport.date(german, 2026, 9, 1), calendar: german)

        XCTAssertEqual(americanGrid.firstDay, CalendarTestSupport.date(american, 2026, 8, 30))
        XCTAssertEqual(germanGrid.firstDay, CalendarTestSupport.date(german, 2026, 8, 31))
        XCTAssertEqual(americanGrid.weeks.count, 5)
        XCTAssertEqual(germanGrid.weeks.count, 5)
        XCTAssertTrue(americanGrid.weeks.allSatisfy { $0.days.count == CalendarGrid.columns })
    }

    func testMultiDayEventSpansWeekRowsInAmericanWeeks() throws {
        let calendar = CalendarTestSupport.calendar("en_US")
        let grid = CalendarGrid(month: CalendarTestSupport.date(calendar, 2026, 9, 1), calendar: calendar)
        let entry = try trip(calendar)

        let spans = grid.spans(for: [entry]).sorted { $0.weekIndex < $1.weekIndex }

        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].weekIndex, 0)
        XCTAssertEqual(spans[0].startColumn, 4)
        XCTAssertEqual(spans[0].length, 3)
        XCTAssertFalse(spans[0].continuesBefore)
        XCTAssertTrue(spans[0].continuesAfter)
        XCTAssertEqual(spans[1].weekIndex, 1)
        XCTAssertEqual(spans[1].startColumn, 0)
        XCTAssertEqual(spans[1].length, 3)
        XCTAssertTrue(spans[1].continuesBefore)
        XCTAssertFalse(spans[1].continuesAfter)
    }

    func testMultiDayEventSpansWeekRowsInGermanWeeks() throws {
        let calendar = CalendarTestSupport.calendar("de_DE")
        let grid = CalendarGrid(month: CalendarTestSupport.date(calendar, 2026, 9, 1), calendar: calendar)
        let entry = try trip(calendar)

        let spans = grid.spans(for: [entry]).sorted { $0.weekIndex < $1.weekIndex }

        XCTAssertEqual(spans.count, 2)
        XCTAssertEqual(spans[0].weekIndex, 0)
        XCTAssertEqual(spans[0].startColumn, 3)
        XCTAssertEqual(spans[0].length, 4)
        XCTAssertTrue(spans[0].continuesAfter)
        XCTAssertEqual(spans[1].weekIndex, 1)
        XCTAssertEqual(spans[1].startColumn, 0)
        XCTAssertEqual(spans[1].length, 2)
        XCTAssertTrue(spans[1].continuesBefore)
    }

    func testSingleDayEventProducesNoSpan() throws {
        let calendar = CalendarTestSupport.calendar("en_US")
        let grid = CalendarGrid(month: CalendarTestSupport.date(calendar, 2026, 9, 1), calendar: calendar)
        let event = CalendarTestSupport.event(
            calendar,
            title: "Dentist",
            start: CalendarTestSupport.date(calendar, 2026, 9, 4, 9),
            end: CalendarTestSupport.date(calendar, 2026, 9, 4, 10)
        )
        let entry = try XCTUnwrap(CalendarEntry(event: event, calendar: calendar))

        XCTAssertTrue(grid.spans(for: [entry]).isEmpty)
    }

    func testOverlappingSpansTakeSeparateLanes() throws {
        let calendar = CalendarTestSupport.calendar("en_US")
        let grid = CalendarGrid(month: CalendarTestSupport.date(calendar, 2026, 9, 1), calendar: calendar)
        let first = try trip(calendar)
        let second = try XCTUnwrap(
            CalendarEntry(
                event: CalendarTestSupport.event(
                    calendar,
                    title: "Parents visiting",
                    start: CalendarTestSupport.date(calendar, 2026, 9, 4, 12),
                    end: CalendarTestSupport.date(calendar, 2026, 9, 6, 12)
                ),
                calendar: calendar
            )
        )

        let spans = grid.spans(for: [first, second])
        let firstWeek = spans.filter { $0.weekIndex == 0 }

        XCTAssertEqual(Set(firstWeek.map(\.lane)), [0, 1])
        XCTAssertEqual(grid.laneCount(in: 0, spans: spans), 2)
    }

    func testAllDayEventWithExclusiveMidnightEndKeepsItsLastDay() throws {
        let calendar = CalendarTestSupport.calendar("en_US")
        let event = CalendarTestSupport.event(
            calendar,
            title: "Imported all day",
            start: CalendarTestSupport.date(calendar, 2026, 9, 4),
            end: CalendarTestSupport.date(calendar, 2026, 9, 5),
            isAllDay: true
        )
        let entry = try XCTUnwrap(CalendarEntry(event: event, calendar: calendar))

        XCTAssertEqual(entry.endDay, CalendarTestSupport.date(calendar, 2026, 9, 4))
        XCTAssertFalse(entry.spansDays)
    }

    func testWeekdaySymbolsAreRotatedToTheFirstWeekday() {
        let american = CalendarGrid.weekdaySymbols(
            calendar: CalendarTestSupport.calendar("en_US"),
            locale: Locale(identifier: "en_US")
        )
        let german = CalendarGrid.weekdaySymbols(
            calendar: CalendarTestSupport.calendar("de_DE"),
            locale: Locale(identifier: "de_DE")
        )

        XCTAssertEqual(american.count, CalendarGrid.columns)
        XCTAssertEqual(german.count, CalendarGrid.columns)
        XCTAssertEqual(american.first, "S")
        XCTAssertEqual(german.first, "M")
    }

    private func trip(_ calendar: Calendar) throws -> CalendarEntry {
        let event = CalendarTestSupport.event(
            calendar,
            title: "Lisbon",
            start: CalendarTestSupport.date(calendar, 2026, 9, 3, 10),
            end: CalendarTestSupport.date(calendar, 2026, 9, 8, 18),
            kind: .trip
        )
        return try XCTUnwrap(CalendarEntry(event: event, calendar: calendar))
    }
}
