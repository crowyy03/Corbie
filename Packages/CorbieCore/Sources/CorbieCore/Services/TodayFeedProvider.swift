import Foundation

public struct TodayFeedProvider: Sendable {
    private let repositories: Repositories
    private let unifiedTasks: UnifiedTaskProvider
    private let calendar: Calendar
    private let locale: Locale

    public init(repositories: Repositories, calendar: Calendar = .current, locale: Locale = .current) {
        self.repositories = repositories
        unifiedTasks = UnifiedTaskProvider(repositories: repositories)
        self.calendar = calendar
        self.locale = locale
    }

    public func feed(space: SpaceDTO, viewerMemberId: UUID?, now: Date = Date()) async throws -> TodayFeed {
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return TodayFeed(day: dayStart)
        }
        let members = try await repositories.members.members(spaceId: space.id)
        let people = try await repositories.people.people(spaceId: space.id)
        let open = try await unifiedTasks.unifiedTasks(TaskQuery(spaceId: space.id))
        let day = try await daySummary(
            space: space,
            viewerMemberId: viewerMemberId,
            open: open,
            now: now,
            dayStart: dayStart,
            dayEnd: dayEnd
        )
        let shown = Set(day.tasksToday.map(\.id)).union(day.eventsToday.map(\.id))
        let free = open.filter { $0.isFree && $0.source == .task && shown.contains($0.id) == false }
        let viewer = members.first { $0.id == viewerMemberId }
        return TodayFeed(
            day: day.day,
            daysTogether: day.daysTogether,
            plans: day.plans,
            tasksToday: day.tasksToday,
            eventsToday: day.eventsToday,
            freeTasks: Array(free.prefix(TodayFeed.freeTaskLimit)),
            freeTasksRemaining: max(0, free.count - TodayFeed.freeTaskLimit),
            comingUp: try await comingUp(
                space: space,
                members: members,
                people: people,
                viewerMemberId: viewerMemberId,
                now: now,
                dayEnd: dayEnd
            ),
            waiting: try await waiting(space: space, viewer: viewer, members: members, now: now),
            recap: try await recap(space: space, members: members, people: people, viewer: viewer, now: now),
            isPaired: members.count >= 2
        )
    }

    public func daySummary(space: SpaceDTO, viewerMemberId: UUID?, now: Date = Date()) async throws -> TodayDaySummary {
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return TodayDaySummary(day: dayStart)
        }
        return try await daySummary(
            space: space,
            viewerMemberId: viewerMemberId,
            open: try await unifiedTasks.unifiedTasks(TaskQuery(spaceId: space.id)),
            now: now,
            dayStart: dayStart,
            dayEnd: dayEnd
        )
    }

    private func daySummary(
        space: SpaceDTO,
        viewerMemberId: UUID?,
        open: [UnifiedTask],
        now: Date,
        dayStart: Date,
        dayEnd: Date
    ) async throws -> TodayDaySummary {
        let planOfStep = try await planIdByStep(spaceId: space.id)
        return TodayDaySummary(
            day: dayStart,
            daysTogether: ImportantDates.daysTogether(space: space, now: now, calendar: calendar),
            plans: try await plans(spaceId: space.id),
            tasksToday: tasksToday(
                open: open,
                viewerMemberId: viewerMemberId,
                dayStart: dayStart,
                dayEnd: dayEnd
            ),
            eventsToday: try await eventsToday(
                spaceId: space.id,
                open: open,
                planOfStep: planOfStep,
                dayStart: dayStart,
                dayEnd: dayEnd
            )
        )
    }

    public func recapSummary(space: SpaceDTO, week: RecapWeek) async throws -> RecapSummary {
        let members = try await repositories.members.members(spaceId: space.id)
        let people = try await repositories.people.people(spaceId: space.id)
        return try await recapSummary(space: space, members: members, people: people, week: week)
    }

    private func tasksToday(
        open: [UnifiedTask],
        viewerMemberId: UUID?,
        dayStart: Date,
        dayEnd: Date
    ) -> [TodayEntry] {
        let mine = open.filter { task in
            guard task.source == .task, let dueAt = task.dueAt, dueAt >= dayStart, dueAt < dayEnd else { return false }
            return task.isFree || task.assigneeMemberId == viewerMemberId
        }
        return TodayEntry.ordered(mine.map { TodayEntry(task: $0, planId: nil, calendar: calendar) })
    }

    private func eventsToday(
        spaceId: UUID,
        open: [UnifiedTask],
        planOfStep: [UUID: UUID],
        dayStart: Date,
        dayEnd: Date
    ) async throws -> [TodayEntry] {
        let events = try await repositories.events.events(spaceId: spaceId, from: dayStart, to: dayEnd)
        var entries = events
            .filter { event in
                guard let startAt = event.startAt else { return false }
                return startAt >= dayStart && startAt < dayEnd
            }
            .map(TodayEntry.init(event:))
        for step in open where step.source != .task {
            guard let dueAt = step.dueAt, dueAt >= dayStart, dueAt < dayEnd else { continue }
            entries.append(TodayEntry(task: step, planId: planOfStep[step.id], calendar: calendar))
        }
        return TodayEntry.ordered(entries)
    }

    private func planIdByStep(spaceId: UUID) async throws -> [UUID: UUID] {
        let steps = try await repositories.plans.datedSteps(spaceId: spaceId)
        return steps.reduce(into: [:]) { result, step in
            result[step.id] = step.planId
        }
    }

    private func comingUp(
        space: SpaceDTO,
        members: [MemberDTO],
        people: [PersonDTO],
        viewerMemberId: UUID?,
        now: Date,
        dayEnd: Date
    ) async throws -> [UpcomingDate] {
        let dates = try await UpcomingDatesProvider(repositories: repositories, calendar: calendar).dates(
            space: space,
            members: members,
            people: people,
            viewerMemberId: viewerMemberId,
            now: now,
            eventsFrom: dayEnd
        )
        return Array(dates.prefix(TodayFeed.comingUpLimit))
    }

    private func plans(spaceId: UUID) async throws -> [TodayPlan] {
        let active = try await repositories.plans.plans(spaceId: spaceId, statuses: [.active])
        return active
            .sorted(by: TodayFeedProvider.endingSoonestFirst)
            .map { TodayPlan($0, locale: locale) }
    }

    private static func endingSoonestFirst(_ lhs: PlanDTO, _ rhs: PlanDTO) -> Bool {
        switch (lhs.endAt, rhs.endAt) {
        case let (left?, right?):
            return left == right ? newestFirst(lhs, rhs) : left < right
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return newestFirst(lhs, rhs)
        }
    }

    private static func newestFirst(_ lhs: PlanDTO, _ rhs: PlanDTO) -> Bool {
        let left = lhs.createdAt ?? .distantPast
        let right = rhs.createdAt ?? .distantPast
        if left != right { return left > right }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private func waiting(
        space: SpaceDTO,
        viewer: MemberDTO?,
        members: [MemberDTO],
        now: Date
    ) async throws -> [TodayWaitingItem] {
        guard let viewerId = viewer?.id else { return [] }
        var result: [TodayWaitingItem] = []
        let capsules = try await repositories.capsules.capsules(spaceId: space.id)
        for capsule in capsules where capsule.isUnlocked(at: now) {
            guard capsule.openedByMemberIds.contains(viewerId) == false else { continue }
            result.append(.capsule(capsule))
        }
        let votes = try await repositories.votes.votes(spaceId: space.id)
        for vote in votes where vote.responses.hasAnswered(viewerId) == false {
            result.append(.vote(vote))
        }
        guard let partner = members.first(where: { $0.id != viewerId }), members.count >= 2 else { return result }
        let since = viewer?.lastUsVisitAt ?? .distantPast
        let wishes = try await repositories.wishes.wishes(
            WishQuery(spaceId: space.id, owner: .member(partner.id), fulfilled: false)
        )
        let fresh = wishes.filter { ($0.createdAt ?? .distantPast) > since }
        if fresh.isEmpty == false {
            result.append(.partnerWishes(count: fresh.count))
        }
        return result
    }

    private func recap(
        space: SpaceDTO,
        members: [MemberDTO],
        people: [PersonDTO],
        viewer: MemberDTO?,
        now: Date
    ) async throws -> RecapSummary? {
        guard RecapSchedule.isCardVisible(
            now: now,
            lastSeenAt: viewer?.lastRecapSeenAt,
            calendar: calendar
        ) else { return nil }
        return try await recapSummary(
            space: space,
            members: members,
            people: people,
            week: RecapSchedule.week(closing: now, calendar: calendar)
        )
    }

    private func recapSummary(
        space: SpaceDTO,
        members: [MemberDTO],
        people: [PersonDTO],
        week: RecapWeek
    ) async throws -> RecapSummary {
        let tasks = try await repositories.tasks.tasks(
            TaskQuery(spaceId: space.id, done: .any)
        )
        let plans = try await repositories.plans.plans(
            spaceId: space.id,
            statuses: [.active, .completed]
        )
        let plansRepository = repositories.plans
        var steps: [PlanStepDTO] = []
        var expenses: [PlanExpenseDTO] = []
        try await withThrowingTaskGroup(of: ([PlanStepDTO], [PlanExpenseDTO]).self) { group in
            for plan in plans {
                group.addTask {
                    async let steps = plansRepository.steps(planId: plan.id)
                    async let expenses = plansRepository.expenses(planId: plan.id)
                    return (try await steps, try await expenses)
                }
            }
            for try await (planSteps, planExpenses) in group {
                steps.append(contentsOf: planSteps)
                expenses.append(contentsOf: planExpenses)
            }
        }
        let horizon = calendar.date(byAdding: .day, value: 7, to: week.end)
        let events = try await repositories.events.events(spaceId: space.id, from: week.end, to: horizon)
        let wishes = try await repositories.wishes.wishes(
            WishQuery(spaceId: space.id, owner: .any, fulfilled: nil)
        )
        return RecapBuilder(calendar: calendar).summary(
            RecapInput(
                space: space,
                members: members,
                tasks: tasks,
                steps: steps,
                plans: plans,
                expenses: expenses,
                events: events,
                wishes: wishes,
                people: people
            ),
            week: week
        )
    }
}
