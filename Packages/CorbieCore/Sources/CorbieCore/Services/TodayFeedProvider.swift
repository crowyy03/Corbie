import Foundation

public struct TodayFeedProvider: Sendable {
    public static let comingUpHorizonDays = 400

    private let repositories: Repositories
    private let unifiedTasks: UnifiedTaskProvider
    private let calendar: Calendar

    public init(repositories: Repositories, calendar: Calendar = .current) {
        self.repositories = repositories
        unifiedTasks = UnifiedTaskProvider(repositories: repositories)
        self.calendar = calendar
    }

    public func feed(space: SpaceDTO, viewerMemberId: UUID?, now: Date = Date()) async throws -> TodayFeed {
        let dayStart = calendar.startOfDay(for: now)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return TodayFeed(day: dayStart)
        }
        let members = try await repositories.members.members(spaceId: space.id)
        let people = try await repositories.people.people(spaceId: space.id)
        let open = try await unifiedTasks.unifiedTasks(TaskQuery(spaceId: space.id))
        let planOfStep = try await planIdByStep(spaceId: space.id)
        let entries = try await todayEntries(
            spaceId: space.id,
            open: open,
            planOfStep: planOfStep,
            dayStart: dayStart,
            dayEnd: dayEnd
        )
        let entryIds = Set(entries.map(\.id))
        let free = open.filter { $0.isFree && $0.source == .task && entryIds.contains($0.id) == false }
        let viewer = members.first { $0.id == viewerMemberId }
        return TodayFeed(
            day: dayStart,
            daysTogether: ImportantDates.daysTogether(space: space, now: now, calendar: calendar),
            entries: entries,
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
            plan: try await plan(spaceId: space.id),
            waiting: try await waiting(space: space, viewer: viewer, members: members, now: now),
            recap: try await recap(space: space, members: members, people: people, viewer: viewer, now: now),
            isPaired: members.count >= 2
        )
    }

    public func recapSummary(space: SpaceDTO, week: RecapWeek) async throws -> RecapSummary {
        let members = try await repositories.members.members(spaceId: space.id)
        let people = try await repositories.people.people(spaceId: space.id)
        return try await recapSummary(space: space, members: members, people: people, week: week)
    }

    private func todayEntries(
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
        for task in open {
            guard let dueAt = task.dueAt, dueAt >= dayStart, dueAt < dayEnd else { continue }
            entries.append(TodayEntry(task: task, planId: planOfStep[task.id], calendar: calendar))
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
    ) async throws -> [TodayDate] {
        let provider = AutoDatesProvider(calendar: calendar)
        let radar = RadarService(calendar: calendar)
        let partner = members.first { $0.id != viewerMemberId }
        let partnerWishes: [WishDTO]
        if let partner, members.count >= 2 {
            partnerWishes = try await repositories.wishes.wishes(
                WishQuery(spaceId: space.id, owner: .member(partner.id), fulfilled: nil)
            )
        } else {
            partnerWishes = []
        }
        let input = RadarInput(
            space: space,
            members: members,
            people: people,
            partnerWishes: partnerWishes,
            viewerMemberId: viewerMemberId
        )
        var result: [TodayDate] = provider
            .upcoming(
                space: space,
                members: members,
                people: people,
                now: now,
                within: TodayFeedProvider.comingUpHorizonDays
            )
            .compactMap { autoDate in
                guard let daysAway = calendar.daysAway(from: now, to: autoDate.date) else { return nil }
                return TodayDate(
                    id: autoDate.id,
                    kind: autoDate.kind,
                    name: autoDate.name,
                    date: autoDate.date,
                    daysAway: daysAway,
                    ordinal: autoDate.years,
                    memberId: autoDate.ownerMemberId,
                    personId: autoDate.personId,
                    radar: daysAway <= RadarService.horizonDays
                        ? radar.radarLine(for: autoDate, input: input, now: now)?.status
                        : nil
                )
            }
        let horizon = calendar.date(byAdding: .day, value: TodayFeedProvider.comingUpHorizonDays, to: now)
        let events = try await repositories.events.events(spaceId: space.id, from: dayEnd, to: horizon)
        for event in events {
            guard let startAt = event.startAt,
                  startAt >= dayEnd,
                  let daysAway = calendar.daysAway(from: now, to: startAt) else { continue }
            result.append(
                TodayDate(
                    id: "event." + event.id.uuidString,
                    kind: .event,
                    name: event.title,
                    date: startAt,
                    daysAway: daysAway,
                    memberId: event.createdByMemberId,
                    eventId: event.id
                )
            )
        }
        return Array(
            result
                .sorted { $0.date == $1.date ? $0.id < $1.id : $0.date < $1.date }
                .prefix(TodayFeed.comingUpLimit)
        )
    }

    private func plan(spaceId: UUID) async throws -> PlanDTO? {
        let plans = try await repositories.plans.plans(spaceId: spaceId, statuses: [.active])
        let dated = plans.filter { $0.endAt != nil }
        if dated.isEmpty == false {
            return dated.min { ($0.endAt ?? .distantFuture) < ($1.endAt ?? .distantFuture) }
        }
        return plans.max { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
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
        var steps: [PlanStepDTO] = []
        var expenses: [PlanExpenseDTO] = []
        for plan in plans {
            steps.append(contentsOf: try await repositories.plans.steps(planId: plan.id))
            expenses.append(contentsOf: try await repositories.plans.expenses(planId: plan.id))
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
