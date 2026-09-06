import CorbieCore
import XCTest
@testable import Corbie

final class RecapPresentationTests: XCTestCase {
    private let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return value
    }()

    private var presentation: RecapPresentation {
        RecapPresentation(locale: Locale(identifier: "en_US"), calendar: calendar)
    }

    private func move(delta: Double, progress: Double = 0.48) -> RecapPlanMove {
        RecapPlanMove(planId: UUID(), title: "Japan", delta: delta, currency: "EUR", progress: progress)
    }

    func testAPlanLineCarriesTheTitleTheDeltaAndThePercent() {
        XCTAssertEqual(presentation.planLine(move(delta: 300)), "Japan +€300, 48%")
    }

    func testMoneyTakenBackReadsAsAMinus() {
        XCTAssertEqual(presentation.deltaText(move(delta: -120)), "-€120")
    }

    func testThePercentIsRoundedToWholeNumbers() {
        XCTAssertEqual(presentation.percentText(0.486), "49%")
        XCTAssertEqual(presentation.percentText(0), "0%")
        XCTAssertEqual(presentation.percentText(1), "100%")
    }

    func testAMilestoneSaysHowManyDaysLandNextWeek() {
        let milestone = RecapMilestone(days: 1000, date: Date())
        XCTAssertEqual(presentation.milestoneLine(milestone), "1,000 days together next week")
    }

    func testAnUpcomingEventKeepsItsOwnTitle() {
        let item = RecapUpcoming(
            id: "event.1",
            kind: .event,
            name: "Dentist",
            date: Date(),
            eventId: UUID()
        )
        XCTAssertEqual(presentation.upcomingTitle(item), "Dentist")
    }

    func testEveryRecapKeyHasCatalogCopy() {
        let keys = [
            "recap.title",
            "recap.tasks",
            "recap.plan.line",
            "recap.plan.delta.up",
            "recap.plan.delta.down",
            "recap.milestone",
            "recap.open",
            "settings.notifications.weeklyrecap"
        ]
        for key in keys {
            XCTAssertNotEqual(String(localized: String.LocalizationValue(key)), key, key)
        }
    }
}
