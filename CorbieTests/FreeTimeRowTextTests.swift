import CorbieCore
import XCTest
@testable import Corbie

final class FreeTimeRowTextTests: XCTestCase {
    private let calendar = CalendarTestSupport.calendar("en_US")

    private func rowText(_ localeIdentifier: String) -> FreeTimeRowText {
        FreeTimeRowText(locale: Locale(identifier: localeIdentifier), calendar: calendar)
    }

    private func withPlainSpaces(_ text: String) -> String {
        text.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    private func slot(
        _ startHour: Int,
        _ startMinute: Int,
        to endHour: Int,
        _ endMinute: Int = 0,
        day: Int = 10,
        isAllDay: Bool = false,
        partnerLabel: String? = nil
    ) -> FreeSlot {
        FreeSlot(
            start: CalendarTestSupport.date(calendar, 2026, 9, day, startHour, startMinute),
            end: CalendarTestSupport.date(calendar, 2026, 9, day, endHour, endMinute),
            isAllDay: isAllDay,
            partnerLabel: partnerLabel
        )
    }

    func testASlotRunningToTheEndOfTheDayReadsAsAfterItsStart() {
        XCTAssertEqual(
            withPlainSpaces(rowText("en_US").title(for: slot(19, 0, to: 23))),
            "Thu, Sep 10 · after 7:00 PM"
        )
    }

    func testAWholeWindowReadsAsAllDay() {
        XCTAssertEqual(
            withPlainSpaces(rowText("en_US").title(for: slot(8, 0, to: 23, day: 12, isAllDay: true))),
            "Sat, Sep 12 · all day"
        )
    }

    func testABoundedSlotReadsAsBothEnds() {
        XCTAssertEqual(
            withPlainSpaces(rowText("en_US").title(for: slot(10, 0, to: 14, day: 13))),
            "Sun, Sep 13 · 10:00 AM - 2:00 PM"
        )
    }

    func testBritishEnglishUsesATwentyFourHourClockAndItsOwnDateOrder() {
        XCTAssertEqual(
            withPlainSpaces(rowText("en_GB").title(for: slot(19, 0, to: 23))),
            "Thu 10 Sep · after 19:00"
        )
    }

    func testGermanPutsTheDayBeforeTheMonthAndKeepsTheTwentyFourHourClock() {
        let title = rowText("de_DE").title(for: slot(10, 0, to: 14))

        XCTAssertTrue(title.contains("10."), title)
        XCTAssertTrue(title.contains("10:00 - 14:00"), title)
    }

    func testDurationNamesHoursAndMinutes() {
        let hourAndAHalf = rowText("en_US").duration(for: slot(10, 0, to: 11, 30))
        let fourHours = rowText("en_US").duration(for: slot(10, 0, to: 14))

        XCTAssertTrue(hourAndAHalf.contains("1"), hourAndAHalf)
        XCTAssertTrue(hourAndAHalf.contains("30"), hourAndAHalf)
        XCTAssertTrue(fourHours.contains("4"), fourHours)
        XCTAssertFalse(fourHours.contains("30"), fourHours)
    }

    func testThePartnerTimeOnlyShowsWhenTheEngineLabelledTheSlot() {
        let labelled = slot(19, 0, to: 23, partnerLabel: "5:00 PM")

        XCTAssertEqual(
            rowText("en_US").partnerTime(for: labelled, partnerName: "Anna"),
            "5:00 PM for Anna"
        )
        XCTAssertNil(rowText("en_US").partnerTime(for: slot(19, 0, to: 23), partnerName: "Anna"))
    }

    func testTheAccessibilityLabelCarriesEverythingTheRowShows() {
        let labelled = slot(19, 0, to: 23, partnerLabel: "5:00 PM")
        let label = withPlainSpaces(rowText("en_US").accessibilityLabel(for: labelled, partnerName: "Anna"))

        XCTAssertTrue(label.hasPrefix("Thu, Sep 10 · after 7:00 PM, "), label)
        XCTAssertTrue(label.hasSuffix(", 5:00 PM for Anna"), label)
    }
}
