import CorbieCore
import XCTest
@testable import Corbie

final class UsCountersTests: XCTestCase {
    private let viewerId = UUID()
    private let partnerId = UUID()

    func testDaysTogetherAndNextAnniversary() throws {
        let space = SpaceDTO(id: UUID(), togetherSince: try day(2024, 1, 1))
        let counters = UsCounters.make(
            space: space,
            members: [],
            people: [],
            events: [],
            viewerMemberId: viewerId,
            now: try day(2025, 4, 5),
            calendar: calendar
        )
        XCTAssertEqual(counters.daysTogether, 460)
        XCTAssertEqual(counters.next?.daysAway, 271)
        XCTAssertEqual(counters.next?.label, ImportantDateLabel(kind: .anniversary, ordinal: 2))
    }

    func testWeddingWinsWhenItComesFirst() throws {
        let space = SpaceDTO(
            id: UUID(),
            togetherSince: try day(2024, 1, 1),
            weddingDate: try day(2023, 6, 10)
        )
        let counters = UsCounters.make(
            space: space,
            members: [],
            people: [],
            events: [],
            viewerMemberId: viewerId,
            now: try day(2025, 4, 5),
            calendar: calendar
        )
        XCTAssertEqual(counters.next?.label, ImportantDateLabel(kind: .wedding, ordinal: 2))
        XCTAssertEqual(counters.next?.daysAway, 66)
    }

    func testPartnerBirthdayCountsAndOwnBirthdayDoesNot() throws {
        let space = SpaceDTO(id: UUID(), togetherSince: try day(2024, 1, 1))
        let viewer = MemberDTO(id: viewerId, displayName: "Ilya", birthdayMonth: 4, birthdayDay: 10)
        let partner = MemberDTO(id: partnerId, displayName: "Sofia", birthdayMonth: 5, birthdayDay: 1)
        let counters = UsCounters.make(
            space: space,
            members: [viewer, partner],
            people: [],
            events: [],
            viewerMemberId: viewerId,
            now: try day(2025, 4, 5),
            calendar: calendar
        )
        XCTAssertEqual(counters.next?.label, ImportantDateLabel(kind: .partnerBirthday, personName: "Sofia"))
        XCTAssertEqual(counters.next?.daysAway, 26)
    }

    func testAnniversaryEventCountsAndOtherEventsDoNot() throws {
        let space = SpaceDTO(id: UUID(), togetherSince: try day(2024, 1, 1))
        let trip = EventDTO(id: UUID(), title: "Lisbon", startAt: try day(2025, 4, 8), kind: .trip)
        let marker = EventDTO(
            id: UUID(),
            title: "The night we met",
            startAt: try day(2025, 4, 12),
            kind: .anniversary
        )
        let counters = UsCounters.make(
            space: space,
            members: [],
            people: [],
            events: [trip, marker],
            viewerMemberId: viewerId,
            now: try day(2025, 4, 5),
            calendar: calendar
        )
        XCTAssertEqual(
            counters.next?.label,
            ImportantDateLabel(kind: .customEvent, personName: "The night we met")
        )
        XCTAssertEqual(counters.next?.daysAway, 7)
    }

    func testNoSpaceAndNoDates() throws {
        XCTAssertEqual(
            UsCounters.make(
                space: nil,
                members: [],
                people: [],
                events: [],
                viewerMemberId: viewerId,
                now: try day(2025, 4, 5),
                calendar: calendar
            ),
            .empty
        )
        let bare = UsCounters.make(
            space: SpaceDTO(id: UUID()),
            members: [],
            people: [],
            events: [],
            viewerMemberId: viewerId,
            now: try day(2025, 4, 5),
            calendar: calendar
        )
        XCTAssertNil(bare.daysTogether)
        XCTAssertNil(bare.next)
    }

    func testTileCountKeysResolveThroughTheCatalog() {
        let people = String(localized: "us.tile.people.count \(2)")
        XCTAssertNotEqual(people, "us.tile.people.count %lld")
        XCTAssertTrue(people.contains("2"), people)
        let oneCapsule = String(localized: "us.tile.capsules.count \(1)")
        XCTAssertNotEqual(oneCapsule, "us.tile.capsules.count %lld")
        XCTAssertNotEqual(oneCapsule, String(localized: "us.tile.capsules.count \(2)"))
        let votes = String(localized: "us.tile.votes.count \(3)")
        XCTAssertNotEqual(votes, "us.tile.votes.count %lld")
        XCTAssertTrue(votes.contains("3"), votes)
    }

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        return calendar
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        let components = DateComponents(year: year, month: month, day: day, hour: 9)
        return try XCTUnwrap(calendar.date(from: components))
    }
}
