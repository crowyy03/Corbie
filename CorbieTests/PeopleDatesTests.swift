import CorbieCore
import XCTest
@testable import Corbie

final class PeopleDatesTests: XCTestCase {
    private let english = Locale(identifier: "en_US")

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = english
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        return calendar
    }

    private func date(_ text: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = english
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text) ?? Date()
    }

    private var now: Date { date("2026-09-05") }

    private func person(
        birthday: (month: Int, day: Int, year: Int?)? = nil,
        relation: String? = nil,
        dates: [PersonDateDTO] = []
    ) -> PersonDTO {
        PersonDTO(
            id: UUID(),
            name: "Anna",
            relation: relation,
            birthdayMonth: birthday?.month,
            birthdayDay: birthday?.day,
            birthdayYear: birthday?.year,
            dates: dates
        )
    }

    func testTheAgeIsSpelledOutOnlyWhenTheYearIsKnown() {
        let known = person(birthday: (month: 9, day: 12, year: 1992))
        let unknown = person(birthday: (month: 9, day: 12, year: nil))
        XCTAssertEqual(
            PersonBirthday.ageText(known, now: now, calendar: calendar, locale: english),
            "turns 34"
        )
        XCTAssertNil(PersonBirthday.ageText(unknown, now: now, calendar: calendar, locale: english))
    }

    func testTheAgeCountsTheNextBirthdayNotTheLastOne() {
        let passed = person(birthday: (month: 1, day: 3, year: 1992))
        XCTAssertEqual(
            PersonBirthday.ageText(passed, now: now, calendar: calendar, locale: english),
            "turns 35"
        )
        let today = person(birthday: (month: 9, day: 5, year: 2000))
        XCTAssertEqual(
            PersonBirthday.ageText(today, now: now, calendar: calendar, locale: english),
            "turns 26"
        )
    }

    func testTheRowCaptionCarriesTheRelationTheDayAndTheAge() {
        let full = person(birthday: (month: 9, day: 12, year: 1992), relation: "Mom")
        XCTAssertEqual(
            PersonDates.rowCaption(for: full, now: now, calendar: calendar, locale: english),
            "Mom \u{00B7} Sep 12 \u{00B7} turns 34"
        )
        let noYear = person(birthday: (month: 9, day: 12, year: nil), relation: "Mom")
        XCTAssertEqual(
            PersonDates.rowCaption(for: noYear, now: now, calendar: calendar, locale: english),
            "Mom \u{00B7} Sep 12"
        )
        let bare = person()
        XCTAssertNil(PersonDates.rowCaption(for: bare, now: now, calendar: calendar, locale: english))
    }

    func testTheBirthdayLineLeadsAndKeepsTheYear() throws {
        let subject = person(
            birthday: (month: 9, day: 12, year: 1992),
            dates: [PersonDateDTO(id: UUID(), title: "wedding day", month: 6, day: 4, year: 2019)]
        )
        let lines = PersonDates.lines(for: subject, now: now, calendar: calendar, locale: english)
        XCTAssertEqual(lines.map(\.title), ["Birthday", "wedding day"])
        XCTAssertTrue(lines[0].isBirthday)
        XCTAssertFalse(lines[1].isBirthday)
        XCTAssertEqual(lines[0].dayText, "Sep 12, 1992")
        XCTAssertEqual(lines[1].dayText, "Jun 4, 2019")
        let birthdayCaption = try XCTUnwrap(lines[0].caption)
        XCTAssertTrue(birthdayCaption.hasSuffix("turns 34"), birthdayCaption)
        let weddingCaption = try XCTUnwrap(lines[1].caption)
        XCTAssertFalse(weddingCaption.contains("turns"), weddingCaption)
    }

    func testAPersonWithoutABirthdayOnlyListsTheirOwnDates() {
        let subject = person(dates: [PersonDateDTO(id: UUID(), title: "moving day", month: 4, day: 1)])
        let lines = PersonDates.lines(for: subject, now: now, calendar: calendar, locale: english)
        XCTAssertEqual(lines.map(\.title), ["moving day"])
        XCTAssertEqual(lines[0].dayText, "Apr 1")
    }

    func testDatesAreSortedThroughTheYear() {
        let december = PersonDateDTO(id: UUID(), title: "moving day", month: 12, day: 1)
        let june = PersonDateDTO(id: UUID(), title: "wedding day", month: 6, day: 4)
        let earlyJune = PersonDateDTO(id: UUID(), title: "first date", month: 6, day: 1)
        let sorted = [december, june, earlyJune].sorted(by: PersonDateDTO.inCalendarOrder)
        XCTAssertEqual(sorted.map(\.title), ["first date", "wedding day", "moving day"])
        let subject = person(dates: sorted)
        XCTAssertEqual(
            PersonDates.lines(for: subject, now: now, calendar: calendar, locale: english).map(\.title),
            ["first date", "wedding day", "moving day"]
        )
    }

    func testADateWithoutADayHasNoTextAndNoCaption() {
        let subject = person(dates: [PersonDateDTO(id: UUID(), title: "someday", month: nil, day: nil)])
        let lines = PersonDates.lines(for: subject, now: now, calendar: calendar, locale: english)
        XCTAssertEqual(lines.map(\.title), ["someday"])
        XCTAssertNil(lines[0].dayText)
        XCTAssertNil(lines[0].caption)
    }

    func testAPersonDateBecomesAYearlyEventForTheCalendarAndTheRadar() throws {
        let wedding = PersonDateDTO(id: UUID(), title: "wedding day", month: 9, day: 12)
        let subject = person(dates: [wedding])
        let autoDates = AutoDatesProvider(calendar: calendar).autoDates(
            space: SpaceDTO(id: UUID()),
            members: [],
            people: [subject],
            now: now
        )
        let autoDate = try XCTUnwrap(autoDates.first)
        XCTAssertEqual(autoDate.kind, .event)
        XCTAssertEqual(autoDate.name, "Anna: wedding day")
        let entry = CalendarEntry(autoDate: autoDate, calendar: calendar)
        XCTAssertEqual(entry.kind, .event)
        XCTAssertEqual(
            CalendarFormatting(locale: english, calendar: calendar).title(for: entry),
            "Anna: wedding day"
        )
    }

    func testAKnownBirthYearNamesTheBirthdayInTheCalendar() throws {
        let subject = person(birthday: (month: 9, day: 12, year: 1992))
        let autoDates = AutoDatesProvider(calendar: calendar).autoDates(
            space: SpaceDTO(id: UUID()),
            members: [],
            people: [subject],
            now: now
        )
        let autoDate = try XCTUnwrap(autoDates.first)
        let entry = CalendarEntry(autoDate: autoDate, calendar: calendar)
        let formatting = CalendarFormatting(locale: english, calendar: calendar)
        XCTAssertEqual(formatting.title(for: entry), "Anna's 34th birthday")
        let plain = person(birthday: (month: 9, day: 12, year: nil))
        let plainDates = AutoDatesProvider(calendar: calendar).autoDates(
            space: SpaceDTO(id: UUID()),
            members: [],
            people: [plain],
            now: now
        )
        let plainEntry = CalendarEntry(autoDate: try XCTUnwrap(plainDates.first), calendar: calendar)
        XCTAssertEqual(formatting.title(for: plainEntry), "Anna's birthday")
    }
}
