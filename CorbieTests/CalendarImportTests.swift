import CorbieCore
import XCTest
@testable import Corbie

final class CalendarImportTests: XCTestCase {
    private let calendar = CalendarTestSupport.calendar("en_US")
    private let spaceId = UUID()

    func testImportSkipsEventsAlreadyInTheSpace() {
        let start = CalendarTestSupport.date(calendar, 2026, 9, 4, 9)
        let existing = CalendarTestSupport.event(calendar, title: "Dentist", start: start)
        let imported = [
            importedEvent(title: "Dentist", start: start),
            importedEvent(title: "Flight", start: CalendarTestSupport.date(calendar, 2026, 9, 6, 7))
        ]

        let drafts = CalendarImport.drafts(
            from: imported,
            existing: [existing],
            spaceId: spaceId,
            createdByMemberId: nil
        )

        XCTAssertEqual(drafts.map(\.title), ["Flight"])
    }

    func testImportIgnoresCaseAndPaddingInTitles() {
        let start = CalendarTestSupport.date(calendar, 2026, 9, 4, 9)
        let existing = CalendarTestSupport.event(calendar, title: "Dentist", start: start)

        let drafts = CalendarImport.drafts(
            from: [importedEvent(title: "  dentist  ", start: start)],
            existing: [existing],
            spaceId: spaceId,
            createdByMemberId: nil
        )

        XCTAssertTrue(drafts.isEmpty)
    }

    func testSameTitleOnAnotherDayIsImported() {
        let existing = CalendarTestSupport.event(
            calendar,
            title: "Dentist",
            start: CalendarTestSupport.date(calendar, 2026, 9, 4, 9)
        )

        let drafts = CalendarImport.drafts(
            from: [importedEvent(title: "Dentist", start: CalendarTestSupport.date(calendar, 2026, 10, 4, 9))],
            existing: [existing],
            spaceId: spaceId,
            createdByMemberId: nil
        )

        XCTAssertEqual(drafts.count, 1)
    }

    func testDuplicatesInsideOneImportCollapse() {
        let start = CalendarTestSupport.date(calendar, 2026, 9, 4, 9)
        let drafts = CalendarImport.drafts(
            from: [importedEvent(title: "Dentist", start: start), importedEvent(title: "Dentist", start: start)],
            existing: [],
            spaceId: spaceId,
            createdByMemberId: nil
        )

        XCTAssertEqual(drafts.count, 1)
    }

    func testImportedDraftsCarryTheSpaceAndTheAuthor() {
        let memberId = UUID()
        let drafts = CalendarImport.drafts(
            from: [
                importedEvent(
                    title: "Flight",
                    start: CalendarTestSupport.date(calendar, 2026, 9, 6, 7),
                    end: CalendarTestSupport.date(calendar, 2026, 9, 6, 11),
                    location: "Lisbon"
                )
            ],
            existing: [],
            spaceId: spaceId,
            createdByMemberId: memberId
        )

        XCTAssertEqual(drafts.count, 1)
        XCTAssertEqual(drafts[0].spaceId, spaceId)
        XCTAssertEqual(drafts[0].createdByMemberId, memberId)
        XCTAssertEqual(drafts[0].kind, .event)
        XCTAssertEqual(drafts[0].locationName, "Lisbon")
    }

    private func importedEvent(
        title: String,
        start: Date,
        end: Date? = nil,
        location: String? = nil
    ) -> ImportedEvent {
        ImportedEvent(
            id: UUID().uuidString,
            calendarId: "calendar",
            title: title,
            startAt: start,
            endAt: end,
            isAllDay: false,
            locationName: location
        )
    }
}
