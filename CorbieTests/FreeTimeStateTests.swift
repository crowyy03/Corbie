import CorbieCore
import XCTest
@testable import Corbie

final class FreeTimeStateTests: XCTestCase {
    private let calendar = CalendarTestSupport.calendar("en_US")

    private var slot: FreeSlot {
        FreeSlot(
            start: CalendarTestSupport.date(calendar, 2026, 9, 10, 19, 0),
            end: CalendarTestSupport.date(calendar, 2026, 9, 10, 23, 0),
            isAllDay: false,
            partnerLabel: nil
        )
    }

    func testSlotsArriveAsSlots() {
        XCTAssertEqual(FreeTimeState.from(.slots([slot])), .slots([slot]))
    }

    func testAnEmptyListOfSlotsIsTheSameAsNoSlots() {
        XCTAssertEqual(FreeTimeState.from(.slots([])), .noSlots)
        XCTAssertEqual(FreeTimeState.from(FreeSlotResult.none), .noSlots)
    }

    func testMissingDataNamesWhoIsMissing() {
        XCTAssertEqual(FreeTimeState.from(.partnerHasNoData), .partnerNotSharing)
        XCTAssertEqual(FreeTimeState.from(.viewerHasNoData), .viewerNotSharing)
    }

    func testEveryEmptyStateReportsItsOwnAnalyticsReason() {
        XCTAssertEqual(FreeTimeState.notPaired.emptyReason, .notPaired)
        XCTAssertEqual(FreeTimeState.viewerNotSharing.emptyReason, .viewerNotSharing)
        XCTAssertEqual(FreeTimeState.partnerNotSharing.emptyReason, .partnerNotSharing)
        XCTAssertEqual(FreeTimeState.calendarDenied.emptyReason, .calendarDenied)
        XCTAssertEqual(FreeTimeState.noSlots.emptyReason, .noSlots)
    }

    func testAFilledOrWorkingScreenReportsNothing() {
        XCTAssertNil(FreeTimeState.loading.emptyReason)
        XCTAssertNil(FreeTimeState.unreadable.emptyReason)
        XCTAssertNil(FreeTimeState.slots([slot]).emptyReason)
    }

    func testTheTwoRangesCoverAWeekAndAFortnight() {
        XCTAssertEqual(FreeTimeRange.allCases.map(\.days), [7, 14])
    }
}
