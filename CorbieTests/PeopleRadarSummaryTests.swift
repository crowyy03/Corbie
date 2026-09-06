import CorbieCore
import XCTest
@testable import Corbie

final class PeopleRadarSummaryTests: XCTestCase {
    private let english = Locale(identifier: "en_US")

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = english
        calendar.timeZone = TimeZone(identifier: "UTC") ?? calendar.timeZone
        return calendar
    }

    private var now: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 9
        components.day = 5
        return calendar.date(from: components) ?? Date()
    }

    private func summary(_ gift: RadarText.Gift, daysAway: Int = 14) -> PeopleRadarSummary {
        PeopleRadarSummary(
            id: "auto.personbirthday.test",
            personId: UUID(),
            name: "Anna",
            text: RadarText(daysAway: daysAway, gift: gift)
        )
    }

    private func lines(for person: PersonDTO) -> [PeopleRadarSummary] {
        let service = RadarService(calendar: calendar)
        let input = RadarInput(space: SpaceDTO(id: UUID()), members: [], people: [person])
        return service.lines(input, now: now).map(PeopleRadarSummary.init)
    }

    func testSavedIdeasWinOverTheEmptyText() {
        XCTAssertEqual(summary(.ideas(3)).text.giftText(locale: english), "3 ideas saved")
        XCTAssertEqual(summary(.ideas(1)).text.giftText(locale: english), "1 idea saved")
        XCTAssertEqual(summary(.nothing).text.giftText(locale: english), "no gift picked")
        XCTAssertEqual(summary(.picked).text.giftText(locale: english), "gift picked")
    }

    func testDaysTextCountsDown() {
        XCTAssertEqual(summary(.nothing, daysAway: 14).text.daysText(locale: english), "14 days to go")
        XCTAssertEqual(summary(.nothing, daysAway: 1).text.daysText(locale: english), "1 day to go")
        XCTAssertEqual(summary(.nothing, daysAway: 0).text.daysText(locale: english), "today")
    }

    func testTheLineJoinsTheCountdownAndTheGift() {
        XCTAssertEqual(
            summary(.ideas(3), daysAway: 14).text.line(locale: english),
            "14 days to go \u{00B7} 3 ideas saved"
        )
    }

    func testAPersonWithIdeasReadsDifferentlyFromOneWithout() throws {
        let withIdeas = PersonDTO(
            id: UUID(),
            name: "Anna",
            birthdayMonth: 9,
            birthdayDay: 12,
            giftIdeaCount: 3
        )
        let withoutIdeas = PersonDTO(
            id: UUID(),
            name: "Mark",
            birthdayMonth: 9,
            birthdayDay: 12
        )
        let saved = try XCTUnwrap(lines(for: withIdeas).first)
        let missing = try XCTUnwrap(lines(for: withoutIdeas).first)
        XCTAssertEqual(saved.text.daysAway, 7)
        XCTAssertEqual(saved.text.giftText(locale: english), "3 ideas saved")
        XCTAssertEqual(missing.text.giftText(locale: english), "no gift picked")
    }

    func testAPickedIdeaFlipsTheText() throws {
        let person = PersonDTO(
            id: UUID(),
            name: "Anna",
            birthdayMonth: 9,
            birthdayDay: 12,
            giftIdeaCount: 3,
            hasPickedGift: true
        )
        let line = try XCTUnwrap(lines(for: person).first)
        XCTAssertEqual(line.text.giftText(locale: english), "gift picked")
    }

    func testABirthdayBeyondTheHorizonProducesNoLine() {
        let person = PersonDTO(id: UUID(), name: "Mark", birthdayMonth: 11, birthdayDay: 2)
        XCTAssertTrue(lines(for: person).isEmpty)
    }

    func testTheNearestDateWinsPerPerson() {
        let personId = UUID()
        let near = PeopleRadarSummary(
            id: "a",
            personId: personId,
            name: "Anna",
            text: RadarText(daysAway: 3, gift: .nothing)
        )
        let far = PeopleRadarSummary(
            id: "b",
            personId: personId,
            name: "Anna",
            text: RadarText(daysAway: 12, gift: .picked)
        )
        let byPerson = PeopleRadarSummary.byPerson([far, near])
        XCTAssertEqual(byPerson[personId], near)
    }

    func testSummariesWithoutAPersonAreNotIndexed() {
        let anniversary = PeopleRadarSummary(
            id: "auto.anniversary.space",
            personId: nil,
            name: nil,
            text: RadarText(daysAway: 5, gift: .nothing)
        )
        XCTAssertTrue(PeopleRadarSummary.byPerson([anniversary]).isEmpty)
    }
}
