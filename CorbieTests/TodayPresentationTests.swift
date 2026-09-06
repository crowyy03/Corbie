import CorbieCore
import XCTest
@testable import Corbie

final class TodayPresentationTests: XCTestCase {
    private let calendar: Calendar = {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return value
    }()

    private var presentation: TodayPresentation {
        TodayPresentation(locale: Locale(identifier: "en_US"), calendar: calendar)
    }

    private func date(_ value: String) -> Date {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = value.count > 10 ? "yyyy-MM-dd HH:mm" : "yyyy-MM-dd"
        return formatter.date(from: value) ?? Date(timeIntervalSince1970: 0)
    }

    func testTheHeaderNamesTheWeekdayAndTheDay() {
        XCTAssertEqual(presentation.headerDate(date("2026-09-06")), "Sunday, September 6")
    }

    private func plainSpaces(_ value: String) -> String {
        value.replacingOccurrences(of: "\u{202F}", with: " ").replacingOccurrences(of: "\u{00A0}", with: " ")
    }

    func testAnAllDayEntryReadsAllDayAndATimedOneReadsTheClock() {
        let timed = TodayEntry(
            event: EventDTO(id: UUID(), title: "Dinner", startAt: date("2026-09-06 19:00"))
        )
        let allDay = TodayEntry(
            event: EventDTO(id: UUID(), title: "Holiday", startAt: date("2026-09-06"), isAllDay: true)
        )
        XCTAssertEqual(plainSpaces(presentation.time(for: timed)), "7:00 PM")
        XCTAssertEqual(presentation.time(for: allDay), "all day")
    }

    func testATaskWithNoClockOnItsDueDateCountsAsAllDay() {
        let task = TodayEntry(
            task: UnifiedTask(id: UUID(), title: "Vet", dueAt: date("2026-09-06"), source: .task),
            planId: nil,
            calendar: calendar
        )
        XCTAssertTrue(task.isAllDay)
        XCTAssertEqual(presentation.time(for: task), "all day")
    }

    func testAPlanStepSaysWhichPlanItCameFrom() {
        XCTAssertEqual(presentation.fromPlan("Japan"), "from plan: Japan")
    }

    func testTheGiftLineCountsIdeasAndFallsBackWhenThereAreNone() {
        let withIdeas = TodayDate(
            id: "a",
            kind: .memberBirthday,
            name: "Sofia",
            date: date("2026-09-10"),
            daysAway: 4,
            radar: RadarStatus(ideasCount: 3, giftPicked: false)
        )
        let without = TodayDate(
            id: "b",
            kind: .memberBirthday,
            name: "Sofia",
            date: date("2026-09-10"),
            daysAway: 4,
            radar: RadarStatus(ideasCount: 0, giftPicked: false)
        )
        XCTAssertTrue(withIdeas.isGiftMissing)
        XCTAssertEqual(presentation.giftLine(withIdeas), "no gift picked · 3 ideas saved")
        XCTAssertEqual(presentation.giftLine(without), "no gift picked")
    }

    func testAPickedGiftClearsTheHighlight() {
        let picked = TodayDate(
            id: "a",
            kind: .memberBirthday,
            name: "Sofia",
            date: date("2026-09-10"),
            daysAway: 4,
            radar: RadarStatus(ideasCount: 3, giftPicked: true)
        )
        XCTAssertFalse(picked.isGiftMissing)
    }

    func testACalendarEventNeverCarriesAGiftHighlight() {
        let event = TodayDate(
            id: "event.1",
            kind: .event,
            name: "Dentist",
            date: date("2026-09-10"),
            daysAway: 4,
            eventId: UUID(),
            radar: RadarStatus(ideasCount: 2, giftPicked: false)
        )
        XCTAssertFalse(event.isGiftMissing)
    }

    func testTheFreeTaskFooterCountsWhatIsHidden() {
        XCTAssertEqual(presentation.moreFreeTasks(4), "4 more")
    }

    func testTheWishRowNamesThePartnerAndCountsTheNewOnes() {
        let text = presentation.waitingWishes(partner: "Sofia", count: 2)
        XCTAssertEqual(text.title, "Wishes from Sofia")
        XCTAssertEqual(text.caption, "2 new")
    }

    func testTheCheckboxLabelFlipsWithTheTask() {
        let open = TodayEntry(
            task: UnifiedTask(id: UUID(), title: "Vet", dueAt: date("2026-09-06"), source: .task),
            planId: nil,
            calendar: calendar
        )
        let done = TodayEntry(
            task: UnifiedTask(
                id: UUID(),
                title: "Vet",
                dueAt: date("2026-09-06"),
                isDone: true,
                source: .task
            ),
            planId: nil,
            calendar: calendar
        )
        XCTAssertEqual(presentation.checkboxLabel(open), "Tick Vet")
        XCTAssertEqual(presentation.checkboxLabel(done), "Untick Vet")
    }

    func testEveryBlockAndQuickActionHasCatalogCopy() {
        let keys = [
            "today.block.plans",
            "today.block.tasks",
            "today.block.events",
            "today.block.freetasks",
            "today.block.comingup",
            "today.block.waiting",
            "today.header.days",
            "today.action.task",
            "today.action.date",
            "today.action.invite",
            "today.waiting.capsule",
            "today.waiting.vote",
            "today.empty.title",
            "today.empty.note"
        ]
        for key in keys {
            XCTAssertNotEqual(String(localized: String.LocalizationValue(key)), key, key)
        }
    }
}
