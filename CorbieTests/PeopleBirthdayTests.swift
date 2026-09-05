import XCTest
@testable import Corbie

final class PeopleBirthdayTests: XCTestCase {
    private let american = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")

    func testAmericanBirthdayPutsTheMonthFirstAndDropsTheYear() throws {
        let text = try XCTUnwrap(PersonBirthday.text(month: 9, day: 12, locale: american))
        XCTAssertEqual(text, "Sep 12")
        XCTAssertFalse(text.contains(String(PersonBirthday.referenceYear)))
    }

    func testGermanBirthdayPutsTheDayFirstAndDropsTheYear() throws {
        let text = try XCTUnwrap(PersonBirthday.text(month: 9, day: 12, locale: german))
        XCTAssertTrue(text.hasPrefix("12."), text)
        XCTAssertFalse(text.contains(String(PersonBirthday.referenceYear)))
        let day = try XCTUnwrap(text.range(of: "12"))
        let month = try XCTUnwrap(text.range(of: "Sep"))
        XCTAssertTrue(day.lowerBound < month.lowerBound, text)
    }

    func testTheTwoLocalesDisagreeOnOrder() throws {
        let american = try XCTUnwrap(PersonBirthday.text(month: 1, day: 3, locale: american))
        let german = try XCTUnwrap(PersonBirthday.text(month: 1, day: 3, locale: german))
        XCTAssertEqual(american, "Jan 3")
        XCTAssertTrue(german.hasPrefix("3."), german)
    }

    func testTheTwentyNinthOfFebruaryIsAValidBirthday() throws {
        let text = try XCTUnwrap(PersonBirthday.text(month: 2, day: 29, locale: american))
        XCTAssertEqual(text, "Feb 29")
    }

    func testImpossibleDatesHaveNoText() {
        XCTAssertNil(PersonBirthday.text(month: 2, day: 30, locale: american))
        XCTAssertNil(PersonBirthday.text(month: 13, day: 1, locale: american))
        XCTAssertNil(PersonBirthday.text(month: nil, day: 12, locale: american))
        XCTAssertNil(PersonBirthday.text(month: 9, day: nil, locale: american))
    }

    func testDayCountFollowsTheMonth() {
        XCTAssertEqual(PersonBirthday.dayCount(month: 1, locale: american), 31)
        XCTAssertEqual(PersonBirthday.dayCount(month: 2, locale: american), 29)
        XCTAssertEqual(PersonBirthday.dayCount(month: 4, locale: american), 30)
    }

    func testClampingKeepsTheDayInsideTheMonth() {
        XCTAssertEqual(PersonBirthday.clampDay(31, month: 2, locale: american), 29)
        XCTAssertEqual(PersonBirthday.clampDay(12, month: 9, locale: american), 12)
        XCTAssertEqual(PersonBirthday.clampDay(0, month: 9, locale: american), 1)
    }

    func testMonthNamesAreLocalized() {
        XCTAssertEqual(PersonBirthday.monthName(9, locale: american), "September")
        XCTAssertEqual(PersonBirthday.monthName(3, locale: german), "März")
    }
}
