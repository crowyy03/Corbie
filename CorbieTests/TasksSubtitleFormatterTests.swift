import CorbieCore
import XCTest
@testable import Corbie

final class TasksSubtitleFormatterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_757_000_000)
    private let viewer = UUID()
    private let partner = UUID()
    private let formatter = TaskSubtitleFormatter(
        locale: Locale(identifier: "en_US"),
        calendar: Calendar(identifier: .gregorian)
    )

    func testATakenTaskNamesThePartnerAndTheDueDate() {
        let due = now.addingTimeInterval(2 * 86_400)
        let task = TaskDTO(
            id: UUID(),
            title: "Pick up the parcel",
            assigneeMemberId: partner,
            dueAt: due,
            takenAt: now.addingTimeInterval(-86_400),
            createdAt: now.addingTimeInterval(-2 * 86_400)
        )

        let subtitle = formatter.text(for: task, viewerMemberId: viewer, partnerName: "Sofia", now: now)

        XCTAssertTrue(subtitle.hasPrefix("Sofia"), subtitle)
        XCTAssertTrue(subtitle.contains(dueText(for: due)), subtitle)
        XCTAssertTrue(subtitle.contains(" · "), subtitle)
    }

    func testAFreeTaskNamesNobody() {
        let task = TaskDTO(
            id: UUID(),
            title: "Buy milk",
            createdAt: now.addingTimeInterval(-86_400)
        )

        let subtitle = formatter.text(for: task, viewerMemberId: viewer, partnerName: "Sofia", now: now)

        XCTAssertFalse(subtitle.contains("Sofia"), subtitle)
        XCTAssertFalse(subtitle.contains(" · "), subtitle)
    }

    func testAnOverdueTaskReadsDifferentlyFromAComingOne() throws {
        let overdue = TaskDTO(
            id: UUID(),
            title: "Call the landlord",
            assigneeMemberId: viewer,
            dueAt: now.addingTimeInterval(-3 * 86_400),
            takenAt: now.addingTimeInterval(-4 * 86_400),
            createdAt: now.addingTimeInterval(-4 * 86_400)
        )
        var coming = overdue
        coming.dueAt = now.addingTimeInterval(3 * 86_400)

        let overdueSubtitle = formatter.text(for: overdue, viewerMemberId: viewer, partnerName: "Sofia", now: now)
        let comingSubtitle = formatter.text(for: coming, viewerMemberId: viewer, partnerName: "Sofia", now: now)

        XCTAssertNotEqual(overdueSubtitle, comingSubtitle)
        XCTAssertTrue(overdueSubtitle.contains(dueText(for: try XCTUnwrap(overdue.dueAt))), overdueSubtitle)
    }

    private func dueText(for date: Date) -> String {
        RelativeDateText(
            locale: Locale(identifier: "en_US"),
            calendar: Calendar(identifier: .gregorian)
        ).dueText(for: date, now: now)
    }
}
