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

    private func summary(_ status: PeopleRadarSummary.GiftStatus, daysAway: Int = 14) -> PeopleRadarSummary {
        PeopleRadarSummary(id: "auto.personbirthday.test", personId: UUID(), name: "Anna", daysAway: daysAway, giftStatus: status)
    }

    private func lines(for person: PersonDTO) -> [PeopleRadarSummary] {
        let service = RadarService(calendar: calendar)
        let input = RadarInput(space: SpaceDTO(id: UUID()), members: [], people: [person])
        return service.lines(input, now: now).map(PeopleRadarSummary.init)
    }

    func testSavedIdeasWinOverTheEmptyText() {
        XCTAssertEqual(summary(.ideas(3)).giftText(locale: english), "3 ideas saved")
        XCTAssertEqual(summary(.ideas(1)).giftText(locale: english), "1 idea saved")
        XCTAssertEqual(summary(.nothing).giftText(locale: english), "no gift picked")
        XCTAssertEqual(summary(.picked).giftText(locale: english), "gift picked")
    }

    func testAPickedGiftBeatsSavedIdeas() {
        XCTAssertEqual(PeopleRadarSummary.GiftStatus(RadarStatus(ideasCount: 3, giftPicked: true)), .picked)
        XCTAssertEqual(PeopleRadarSummary.GiftStatus(RadarStatus(ideasCount: 3, giftPicked: false)), .ideas(3))
        XCTAssertEqual(PeopleRadarSummary.GiftStatus(RadarStatus(ideasCount: 0, giftPicked: false)), .nothing)
    }

    func testDaysTextCountsDown() {
        XCTAssertEqual(summary(.nothing, daysAway: 14).daysText(locale: english), "14 days to go")
        XCTAssertEqual(summary(.nothing, daysAway: 1).daysText(locale: english), "1 day to go")
        XCTAssertEqual(summary(.nothing, daysAway: 0).daysText(locale: english), "today")
    }

    func testTheLineJoinsTheCountdownAndTheGift() {
        XCTAssertEqual(summary(.ideas(3), daysAway: 14).line(locale: english), "14 days to go \u{00B7} 3 ideas saved")
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
        XCTAssertEqual(saved.daysAway, 7)
        XCTAssertEqual(saved.giftText(locale: english), "3 ideas saved")
        XCTAssertEqual(missing.giftText(locale: english), "no gift picked")
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
        XCTAssertEqual(line.giftText(locale: english), "gift picked")
    }

    func testABirthdayBeyondTheHorizonProducesNoLine() {
        let person = PersonDTO(id: UUID(), name: "Mark", birthdayMonth: 11, birthdayDay: 2)
        XCTAssertTrue(lines(for: person).isEmpty)
    }

    func testTheNearestDateWinsPerPerson() {
        let personId = UUID()
        let near = PeopleRadarSummary(id: "a", personId: personId, name: "Anna", daysAway: 3, giftStatus: .nothing)
        let far = PeopleRadarSummary(id: "b", personId: personId, name: "Anna", daysAway: 12, giftStatus: .picked)
        let byPerson = PeopleRadarSummary.byPerson([far, near])
        XCTAssertEqual(byPerson[personId], near)
    }

    func testSummariesWithoutAPersonAreNotIndexed() {
        let anniversary = PeopleRadarSummary(id: "auto.anniversary.space", personId: nil, name: nil, daysAway: 5, giftStatus: .nothing)
        XCTAssertTrue(PeopleRadarSummary.byPerson([anniversary]).isEmpty)
    }
}
