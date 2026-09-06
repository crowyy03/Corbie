import CorbieCore
import XCTest
@testable import Corbie

final class QARelativeDateTests: XCTestCase {
    private let english = Locale(identifier: "en_US")
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.locale = english
        value.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return value
    }

    private func day(_ offset: Int, from now: Date) -> Date {
        calendar.date(byAdding: .day, value: offset, to: now) ?? now
    }

    func testTheSameDayReadsAsToday() {
        let dates = RelativeDateText(locale: english, calendar: calendar)
        let now = Date()
        XCTAssertEqual(dates.relativeDay(for: now, now: now), "today")
        XCTAssertEqual(dates.relativeDay(for: day(-1, from: now), now: now), "yesterday")
        XCTAssertEqual(dates.relativeDay(for: day(1, from: now), now: now), "tomorrow")
        XCTAssertEqual(dates.relativeDay(for: day(3, from: now), now: now), "in 3 days")
        XCTAssertEqual(dates.relativeDay(for: day(-2, from: now), now: now), "2 days ago")
    }

    func testATaskTakenTodayReadsAsTakenToday() {
        let now = Date()
        let task = TaskDTO(
            id: UUID(),
            title: "Book the vet",
            assigneeMemberId: UUID(),
            takenAt: now,
            createdAt: now
        )
        let subtitle = RelativeDateText(locale: english, calendar: calendar).subtitle(
            for: task,
            viewerMemberId: task.assigneeMemberId,
            partnerName: nil,
            now: now
        )
        XCTAssertEqual(subtitle.relativeDay, "today")
    }
}
