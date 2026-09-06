import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainRecapBuilderTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "UTC")
    private let me = UUID()
    private let partner = UUID()
    private let goalId = UUID()

    private var week: RecapWeek {
        RecapSchedule.week(closing: DomainClock.date("2026-09-06 19:00", in: calendar), calendar: calendar)
    }

    private func date(_ value: String) -> Date {
        DomainClock.date(value, in: calendar)
    }

    private func space(togetherSince: String? = "2023-03-31") -> SpaceDTO {
        SpaceDTO(
            id: UUID(),
            createdAt: date("2023-03-31"),
            creatorMemberId: me,
            togetherSince: togetherSince.map { date($0) }
        )
    }

    private var members: [MemberDTO] {
        [
            MemberDTO(id: me, displayName: "Ilya", colorKey: "ice"),
            MemberDTO(id: partner, displayName: "Sofia", colorKey: "slate")
        ]
    }

    private func doneTask(_ title: String, by memberId: UUID, at value: String) -> TaskDTO {
        TaskDTO(
            id: UUID(),
            title: title,
            isDone: true,
            doneByMemberId: memberId,
            doneAt: date(value),
            createdAt: date("2026-08-01")
        )
    }

    private func seeded() -> RecapInput {
        RecapInput(
            space: space(),
            members: members,
            tasks: [
                doneTask("Vet", by: me, at: "2026-08-31 09:00"),
                doneTask("Bins", by: me, at: "2026-09-06 18:00"),
                doneTask("Bank", by: partner, at: "2026-09-02 12:00"),
                doneTask("Old one", by: me, at: "2026-08-30 12:00"),
                TaskDTO(id: UUID(), title: "Still open", createdAt: date("2026-09-01"))
            ],
            steps: [
                GoalStepDTO(
                    id: UUID(),
                    goalId: goalId,
                    goalTitle: "Japan",
                    title: "Papers",
                    isDone: true,
                    doneByMemberId: partner,
                    doneAt: date("2026-09-03 10:00")
                )
            ],
            goals: [
                GoalDTO(
                    id: goalId,
                    title: "Japan",
                    targetAmount: 5000,
                    currency: "EUR",
                    savedAmount: 2100,
                    addedAmount: 300
                )
            ],
            expenses: [
                GoalExpenseDTO(
                    id: UUID(),
                    goalId: goalId,
                    amount: 300,
                    currency: "EUR",
                    amountInGoalCurrency: 300,
                    date: date("2026-09-04 15:00")
                ),
                GoalExpenseDTO(
                    id: UUID(),
                    goalId: goalId,
                    amount: 50,
                    currency: "EUR",
                    amountInGoalCurrency: 50,
                    date: date("2026-08-20 15:00")
                )
            ],
            events: [
                EventDTO(id: UUID(), title: "Dentist", startAt: date("2026-09-09 10:00")),
                EventDTO(id: UUID(), title: "Too far", startAt: date("2026-09-20 10:00"))
            ],
            wishes: [
                WishDTO(id: UUID(), ownerMemberId: me, addedByMemberId: partner, title: "Lamp", createdAt: date("2026-09-05 08:00")),
                WishDTO(id: UUID(), ownerMemberId: partner, addedByMemberId: partner, title: "Boots", createdAt: date("2026-09-05 09:00")),
                WishDTO(id: UUID(), ownerMemberId: me, addedByMemberId: me, title: "Old wish", createdAt: date("2026-07-01"))
            ]
        )
    }

    @Test func tasksAreCountedPerMemberInsideTheWeekOnly() {
        let summary = RecapBuilder(calendar: calendar).summary(seeded(), week: week)
        #expect(summary.members.map(\.tasksDone) == [2, 2])
        #expect(summary.members.map(\.name) == ["Ilya", "Sofia"])
    }

    @Test func wishesAreCountedAgainstWhoeverAddedThem() {
        let summary = RecapBuilder(calendar: calendar).summary(seeded(), week: week)
        #expect(summary.members.map(\.wishesAdded) == [0, 2])
    }

    @Test func aGoalMovesByTheMoneyAddedInsideTheWeek() throws {
        let summary = RecapBuilder(calendar: calendar).summary(seeded(), week: week)
        let move = try #require(summary.goals.first)
        #expect(summary.goals.count == 1)
        #expect(move.title == "Japan")
        #expect(move.delta == 300)
        #expect(move.currency == "EUR")
        #expect(move.progress == 0.48)
    }

    @Test func onlyTheNextSevenDaysCountAsComingUp() throws {
        let summary = RecapBuilder(calendar: calendar).summary(seeded(), week: week)
        #expect(summary.comingUp.count == 1)
        #expect(summary.comingUp.first?.name == "Dentist")
        #expect(summary.comingUp.first?.kind == .event)
    }

    @Test func daysTogetherIsCountedAtTheEndOfTheWeek() {
        let summary = RecapBuilder(calendar: calendar).summary(seeded(), week: week)
        #expect(summary.daysTogether == 1255)
    }

    @Test func aRoundMilestoneInsideTheComingWeekIsReported() throws {
        var input = seeded()
        input.space = space(togetherSince: "2023-12-16")
        let summary = RecapBuilder(calendar: calendar).summary(input, week: week)
        let milestone = try #require(summary.milestone)
        #expect(summary.daysTogether == 995)
        #expect(milestone.days == 1000)
        #expect(DomainClock.text(milestone.date, in: calendar) == "2026-09-11 00:00")
    }

    @Test func noMilestoneWhenTheRoundNumberIsFurtherOut() {
        var input = seeded()
        input.space = space(togetherSince: "2023-09-21")
        let summary = RecapBuilder(calendar: calendar).summary(input, week: week)
        #expect(summary.daysTogether == 1081)
        #expect(summary.milestone == nil)
    }

    @Test func anEmptyWeekReportsNoActivity() {
        let quiet = RecapInput(space: space(), members: members)
        let summary = RecapBuilder(calendar: calendar).summary(quiet, week: week)
        #expect(summary.hasActivity == false)
        #expect(summary.isPaired)
        #expect(summary.members.allSatisfy { $0.tasksDone == 0 && $0.wishesAdded == 0 })
    }

    @Test func aSoloSpaceIsNotPaired() {
        var input = seeded()
        input.members = [MemberDTO(id: me, displayName: "Ilya", colorKey: "ice")]
        let summary = RecapBuilder(calendar: calendar).summary(input, week: week)
        #expect(summary.isPaired == false)
        #expect(summary.hasActivity)
    }
}
