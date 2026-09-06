import CorbieCore
import XCTest
@testable import Corbie

final class FreeTimeCorbieEventTests: XCTestCase {
    private let calendar = CalendarTestSupport.calendar("en_US")

    private func date(_ day: Int, _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0) -> Date {
        let components = DateComponents(
            year: 2026,
            month: 9,
            day: day,
            hour: hour,
            minute: minute,
            second: second
        )
        return calendar.date(from: components) ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    func testATimedEventBecomesItsOwnInterval() {
        let event = CalendarTestSupport.event(
            calendar,
            title: "Dentist",
            start: date(10, 14),
            end: date(10, 15, 30)
        )

        XCTAssertEqual(
            CorbieEventBusy.intervals(from: [event], calendar: calendar),
            [DateInterval(start: date(10, 14), end: date(10, 15, 30))]
        )
    }

    func testAnAllDayEventCoversTheWholeLocalDay() {
        let event = CalendarTestSupport.event(
            calendar,
            title: "Moving",
            start: date(10),
            end: date(10, 23, 59, 59),
            isAllDay: true
        )

        XCTAssertEqual(
            CorbieEventBusy.intervals(from: [event], calendar: calendar),
            [DateInterval(start: date(10), end: date(11))]
        )
    }

    func testAnAllDayEventWithoutAnEndStillCoversItsDay() {
        let event = CalendarTestSupport.event(calendar, title: "Moving", start: date(10), isAllDay: true)

        XCTAssertEqual(
            CorbieEventBusy.intervals(from: [event], calendar: calendar),
            [DateInterval(start: date(10), end: date(11))]
        )
    }

    func testATripCoversEveryDayItSpans() {
        let trip = CalendarTestSupport.event(
            calendar,
            title: "Lisbon",
            start: date(10),
            end: date(12, 23, 59, 59),
            isAllDay: true,
            kind: .trip
        )

        XCTAssertEqual(
            CorbieEventBusy.intervals(from: [trip], calendar: calendar),
            [DateInterval(start: date(10), end: date(13))]
        )
    }

    func testYearlyMarkersDoNotBlockTheDay() {
        let birthday = CalendarTestSupport.event(
            calendar,
            title: "Anna",
            start: date(10),
            end: date(10, 23, 59, 59),
            isAllDay: true,
            kind: .birthday
        )
        let anniversary = CalendarTestSupport.event(
            calendar,
            title: "Us",
            start: date(11),
            end: date(11, 23, 59, 59),
            isAllDay: true,
            kind: .anniversary
        )

        XCTAssertTrue(CorbieEventBusy.intervals(from: [birthday, anniversary], calendar: calendar).isEmpty)
    }

    func testATimedEventWithoutAnEndIsNotBusy() {
        let event = CalendarTestSupport.event(calendar, title: "Coffee", start: date(10, 9))

        XCTAssertTrue(CorbieEventBusy.intervals(from: [event], calendar: calendar).isEmpty)
    }

    func testOverlappingEventsMergeIntoOneInterval() {
        let first = CalendarTestSupport.event(calendar, title: "Call", start: date(10, 9), end: date(10, 10, 30))
        let second = CalendarTestSupport.event(calendar, title: "Standup", start: date(10, 10), end: date(10, 11))

        XCTAssertEqual(
            CorbieEventBusy.intervals(from: [second, first], calendar: calendar),
            [DateInterval(start: date(10, 9), end: date(10, 11))]
        )
    }
}
