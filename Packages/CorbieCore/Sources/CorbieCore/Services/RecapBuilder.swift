import Foundation

public struct RecapInput: Sendable {
    public var space: SpaceDTO
    public var members: [MemberDTO]
    public var tasks: [TaskDTO]
    public var steps: [GoalStepDTO]
    public var goals: [GoalDTO]
    public var expenses: [GoalExpenseDTO]
    public var events: [EventDTO]
    public var wishes: [WishDTO]
    public var people: [PersonDTO]

    public init(
        space: SpaceDTO,
        members: [MemberDTO] = [],
        tasks: [TaskDTO] = [],
        steps: [GoalStepDTO] = [],
        goals: [GoalDTO] = [],
        expenses: [GoalExpenseDTO] = [],
        events: [EventDTO] = [],
        wishes: [WishDTO] = [],
        people: [PersonDTO] = []
    ) {
        self.space = space
        self.members = members
        self.tasks = tasks
        self.steps = steps
        self.goals = goals
        self.expenses = expenses
        self.events = events
        self.wishes = wishes
        self.people = people
    }
}

public struct RecapBuilder: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func summary(_ input: RecapInput, week: RecapWeek) -> RecapSummary {
        RecapSummary(
            week: week,
            members: tallies(input, week: week),
            goals: moves(input, week: week),
            comingUp: upcoming(input, week: week),
            daysTogether: ImportantDates.daysTogether(
                space: input.space,
                now: lastMoment(of: week),
                calendar: calendar
            ),
            milestone: milestone(input, week: week)
        )
    }

    private func tallies(_ input: RecapInput, week: RecapWeek) -> [RecapMemberTally] {
        input.members.map { member in
            let tasks = input.tasks.filter { task in
                task.isDone && task.doneByMemberId == member.id && closed(task.doneAt, in: week)
            }
            let steps = input.steps.filter { step in
                step.isDone && step.doneByMemberId == member.id && closed(step.doneAt, in: week)
            }
            let wishes = input.wishes.filter { wish in
                (wish.addedByMemberId ?? wish.ownerMemberId) == member.id && closed(wish.createdAt, in: week)
            }
            return RecapMemberTally(
                memberId: member.id,
                name: member.displayName,
                colorKey: member.colorKey,
                tasksDone: tasks.count + steps.count,
                wishesAdded: wishes.count
            )
        }
    }

    private func moves(_ input: RecapInput, week: RecapWeek) -> [RecapGoalMove] {
        input.goals
            .compactMap { goal -> RecapGoalMove? in
                let delta = input.expenses
                    .filter { $0.goalId == goal.id && closed($0.date, in: week) }
                    .reduce(0) { $0 + $1.amountInGoalCurrency }
                guard delta != 0 else { return nil }
                return RecapGoalMove(
                    goalId: goal.id,
                    title: goal.title,
                    delta: delta,
                    currency: goal.currency,
                    progress: goal.progress
                )
            }
            .sorted { lhs, rhs in
                let left = abs(lhs.delta)
                let right = abs(rhs.delta)
                if left != right { return left > right }
                if lhs.title != rhs.title { return lhs.title < rhs.title }
                return lhs.goalId.uuidString < rhs.goalId.uuidString
            }
            .prefix(RecapSummary.goalLimit)
            .map { $0 }
    }

    private func upcoming(_ input: RecapInput, week: RecapWeek) -> [RecapUpcoming] {
        let from = week.end
        guard let to = calendar.date(byAdding: .day, value: 7, to: from) else { return [] }
        let provider = AutoDatesProvider(calendar: calendar)
        var result: [RecapUpcoming] = provider
            .autoDates(space: input.space, members: input.members, people: input.people, now: from)
            .filter { $0.date >= from && $0.date < to }
            .map { RecapUpcoming(id: $0.id, kind: $0.kind, name: $0.name, date: $0.date) }
        for event in input.events {
            guard let startAt = event.startAt, startAt >= from, startAt < to else { continue }
            result.append(
                RecapUpcoming(
                    id: "event." + event.id.uuidString,
                    kind: .event,
                    name: event.title,
                    date: startAt,
                    eventId: event.id
                )
            )
        }
        return result
            .sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
            .prefix(RecapSummary.upcomingLimit)
            .map { $0 }
    }

    private func milestone(_ input: RecapInput, week: RecapWeek) -> RecapMilestone? {
        guard let togetherSince = input.space.togetherSince,
              let reached = ImportantDates.daysTogether(
                  space: input.space,
                  now: lastMoment(of: week),
                  calendar: calendar
              ) else { return nil }
        guard let days = RecapSchedule.milestones.first(where: { $0 > reached && $0 <= reached + 7 }),
              let date = calendar.date(
                  byAdding: .day,
                  value: days,
                  to: calendar.startOfDay(for: togetherSince)
              ) else { return nil }
        return RecapMilestone(days: days, date: date)
    }

    private func closed(_ date: Date?, in week: RecapWeek) -> Bool {
        guard let date else { return false }
        return week.contains(date)
    }

    private func lastMoment(of week: RecapWeek) -> Date {
        week.end.addingTimeInterval(-1)
    }
}
