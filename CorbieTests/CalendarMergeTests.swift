import CorbieCore
import XCTest
@testable import Corbie

final class CalendarMergeTests: XCTestCase {
    private let calendar = CalendarTestSupport.calendar("en_US")

    func testStoredAndVirtualDatesEndUpInOneSortedList() {
        let dinner = CalendarTestSupport.event(
            calendar,
            title: "Dinner",
            start: CalendarTestSupport.date(calendar, 2026, 9, 10, 19)
        )
        let birthday = CalendarTestSupport.autoDate(
            kind: .personBirthday,
            date: CalendarTestSupport.date(calendar, 2026, 9, 4),
            name: "Anna",
            personId: UUID()
        )
        let anniversary = CalendarTestSupport.autoDate(
            kind: .anniversary,
            date: CalendarTestSupport.date(calendar, 2026, 9, 21),
            years: 2
        )

        let entries = CalendarEntries.merge(
            events: [dinner],
            autoDates: [anniversary, birthday],
            calendar: calendar
        )

        XCTAssertEqual(entries.count, 3)
        XCTAssertEqual(entries.map(\.startDay), [
            CalendarTestSupport.date(calendar, 2026, 9, 4),
            CalendarTestSupport.date(calendar, 2026, 9, 10),
            CalendarTestSupport.date(calendar, 2026, 9, 21)
        ])
        XCTAssertEqual(entries.filter { $0.isStored }.count, 1)
    }

    func testStoredBirthdayHidesTheVirtualOneOnTheSameDay() {
        let personId = UUID()
        let day = CalendarTestSupport.date(calendar, 2026, 9, 4)
        let stored = CalendarTestSupport.event(
            calendar,
            title: "Anna turns 30",
            start: day,
            isAllDay: true,
            kind: .birthday,
            personId: personId
        )
        let virtual = CalendarTestSupport.autoDate(
            kind: .personBirthday,
            date: day,
            name: "Anna",
            personId: personId
        )

        let entries = CalendarEntries.merge(events: [stored], autoDates: [virtual], calendar: calendar)

        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries[0].isStored)
    }

    func testStoredBirthdayOfAnotherPersonKeepsTheVirtualDate() {
        let day = CalendarTestSupport.date(calendar, 2026, 9, 4)
        let stored = CalendarTestSupport.event(
            calendar,
            title: "Anna turns 30",
            start: day,
            isAllDay: true,
            kind: .birthday,
            personId: UUID()
        )
        let virtual = CalendarTestSupport.autoDate(
            kind: .personBirthday,
            date: day,
            name: "Boris",
            personId: UUID()
        )

        let entries = CalendarEntries.merge(events: [stored], autoDates: [virtual], calendar: calendar)

        XCTAssertEqual(entries.count, 2)
    }

    func testStoredAnniversaryHidesBothSpaceAnniversaries() {
        let day = CalendarTestSupport.date(calendar, 2026, 9, 21)
        let stored = CalendarTestSupport.event(
            calendar,
            title: "Two years",
            start: day,
            isAllDay: true,
            kind: .anniversary
        )
        let together = CalendarTestSupport.autoDate(kind: .anniversary, date: day, years: 2)
        let wedding = CalendarTestSupport.autoDate(kind: .wedding, date: day, years: 1)

        let entries = CalendarEntries.merge(events: [stored], autoDates: [together, wedding], calendar: calendar)

        XCTAssertEqual(entries.count, 1)
        XCTAssertTrue(entries[0].isStored)
    }

    func testAllDayEntriesComeFirstWithinADay() {
        let day = CalendarTestSupport.date(calendar, 2026, 9, 4)
        let dinner = CalendarTestSupport.event(calendar, title: "Dinner", start: day.addingTimeInterval(19 * 3600))
        let birthday = CalendarTestSupport.autoDate(kind: .personBirthday, date: day, name: "Anna", personId: UUID())

        let entries = CalendarEntries.merge(events: [dinner], autoDates: [birthday], calendar: calendar)

        XCTAssertTrue(entries[0].isAllDay)
        XCTAssertEqual(entries[1].event?.title, "Dinner")
    }

    func testDayIndexSkipsMultiDayEntries() throws {
        let trip = CalendarTestSupport.event(
            calendar,
            title: "Lisbon",
            start: CalendarTestSupport.date(calendar, 2026, 9, 3, 10),
            end: CalendarTestSupport.date(calendar, 2026, 9, 8, 18),
            kind: .trip
        )
        let dinner = CalendarTestSupport.event(
            calendar,
            title: "Dinner",
            start: CalendarTestSupport.date(calendar, 2026, 9, 4, 19)
        )
        let entries = CalendarEntries.merge(events: [trip, dinner], autoDates: [], calendar: calendar)

        let byDay = CalendarEntries.entriesByDay(entries, calendar: calendar)

        XCTAssertEqual(byDay[CalendarTestSupport.date(calendar, 2026, 9, 4)]?.count, 1)
        XCTAssertNil(byDay[CalendarTestSupport.date(calendar, 2026, 9, 3)])
    }

    func testUpcomingKeepsRunningEventsAndDropsFinishedOnes() {
        let now = CalendarTestSupport.date(calendar, 2026, 9, 4, 12)
        let finished = CalendarTestSupport.event(
            calendar,
            title: "Yesterday",
            start: CalendarTestSupport.date(calendar, 2026, 9, 3, 19)
        )
        let running = CalendarTestSupport.event(
            calendar,
            title: "Lisbon",
            start: CalendarTestSupport.date(calendar, 2026, 9, 3, 10),
            end: CalendarTestSupport.date(calendar, 2026, 9, 8, 18),
            kind: .trip
        )
        let later = CalendarTestSupport.event(
            calendar,
            title: "Dentist",
            start: CalendarTestSupport.date(calendar, 2026, 9, 30, 9)
        )
        let entries = CalendarEntries.merge(events: [finished, running, later], autoDates: [], calendar: calendar)

        let upcoming = CalendarEntries.upcoming(entries, from: now, calendar: calendar, limit: 10)

        XCTAssertEqual(upcoming.map { $0.event?.title }, ["Lisbon", "Dentist"])
    }

    func testUpcomingRespectsTheLimit() {
        let now = CalendarTestSupport.date(calendar, 2026, 9, 1, 8)
        let events = (1...5).map { offset in
            CalendarTestSupport.event(
                calendar,
                title: "Day \(offset)",
                start: CalendarTestSupport.date(calendar, 2026, 9, offset + 1, 9)
            )
        }
        let entries = CalendarEntries.merge(events: events, autoDates: [], calendar: calendar)

        XCTAssertEqual(CalendarEntries.upcoming(entries, from: now, calendar: calendar, limit: 3).count, 3)
    }
}
