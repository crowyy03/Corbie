import CorbieCore
import XCTest
@testable import Corbie

final class FreeWindowCopyTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    private func date(_ text: String) -> Date {
        ISO8601DateFormatter().date(from: text) ?? .distantPast
    }

    private func window() throws -> FreeWindow {
        try XCTUnwrap(FreeWindow(spaceCreatedAt: date("2026-09-20T10:00:00Z"), days: 3, calendar: calendar))
    }

    func testTodaySaysHowManyMoreDaysPremiumIsFree() throws {
        let endsAt = try window().endsAt
        XCTAssertEqual(
            FreeWindowCopy.line(endsAt: endsAt, now: date("2026-09-20T10:00:00Z"), calendar: calendar),
            "Premium is free for 3 more days"
        )
        XCTAssertEqual(
            FreeWindowCopy.line(endsAt: endsAt, now: date("2026-09-22T10:00:00Z"), calendar: calendar),
            "Premium is free for 1 more day"
        )
    }

    func testTheLastDaySaysUntilTonight() throws {
        let endsAt = try window().endsAt
        XCTAssertEqual(
            FreeWindowCopy.line(endsAt: endsAt, now: date("2026-09-23T08:00:00Z"), calendar: calendar),
            "Premium is free until tonight"
        )
    }

    func testSettingsShowTheSameLineAndOfferNoPlansInsideTheWindow() throws {
        let window = try window()
        let now = date("2026-09-21T10:00:00Z")
        let status = SettingsSubscriptionStatus(state: .freeWindow(window), now: now)
        XCTAssertEqual(status.text, FreeWindowCopy.line(endsAt: window.endsAt, now: now))
        XCTAssertFalse(status.showsPlans)
        XCTAssertTrue(SettingsSubscriptionStatus(state: .readOnly).showsPlans)
    }
}
