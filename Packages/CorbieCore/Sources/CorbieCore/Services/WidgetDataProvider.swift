import Foundation

public struct WidgetContext: Sendable {
    public let space: SpaceDTO
    public let members: [MemberDTO]
    public let viewer: MemberDTO?
    public let partner: MemberDTO?
    public let isPremium: Bool

    public init(space: SpaceDTO, members: [MemberDTO], viewer: MemberDTO?, partner: MemberDTO?, isPremium: Bool) {
        self.space = space
        self.members = members
        self.viewer = viewer
        self.partner = partner
        self.isPremium = isPremium
    }

    public func colorKey(for memberId: UUID?) -> String? {
        guard let memberId else { return nil }
        return members.first { $0.id == memberId }?.colorKey
    }

    public func name(for memberId: UUID?) -> String? {
        guard let memberId else { return nil }
        return members.first { $0.id == memberId }?.displayName
    }
}

public struct WidgetDataProvider: Sendable {
    public static let taskLimit = 3
    public static let ourDayLineLimit = 2
    public static let wishLimit = 3
    public static let dateLimit = 3
    public static let shoppingLimit = 3
    public static let freeSlotLimit = 2

    private let controller: PersistenceController
    private let calendar: Calendar
    private let locale: Locale
    private let identity: MemberIdentity
    private let viewerMemberIdOverride: UUID?

    public init(
        controller: PersistenceController,
        calendar: Calendar = .current,
        locale: Locale = .current,
        identity: MemberIdentity = MemberIdentity(),
        viewerMemberId: UUID? = nil
    ) {
        self.controller = controller
        self.calendar = calendar
        self.locale = locale
        self.identity = identity
        viewerMemberIdOverride = viewerMemberId
    }

    public func context(now: Date = Date()) async throws -> WidgetContext? {
        let repositories = controller.repositories
        let identifiedId = try await resolveViewerId(repositories: repositories)
        guard let space = try await repositories.spaces.currentSpace(memberId: identifiedId) else { return nil }
        let members = try await repositories.members.members(spaceId: space.id)
        let viewerId = members.contains { $0.id == identifiedId } ? identifiedId : members.first?.id
        let viewer = members.first { $0.id == viewerId }
        let partner = members.first { $0.id != viewerId }
        return WidgetContext(
            space: space,
            members: members,
            viewer: viewer,
            partner: partner,
            isPremium: WidgetPremiumRule.isPremium(space: space, now: now)
        )
    }

    public func daysTogether(now: Date = Date()) async throws -> DaysTogetherSnapshot {
        guard let context = try await context(now: now) else {
            return DaysTogetherSnapshot(days: nil, isPremium: false)
        }
        return DaysTogetherSnapshot(
            days: ImportantDates.daysTogether(space: context.space, now: now, calendar: calendar),
            isPremium: context.isPremium
        )
    }

    public func countdown(source: CountdownSource, now: Date = Date()) async throws -> CountdownSnapshot {
        guard let context = try await context(now: now) else {
            return CountdownSnapshot(
                kind: nil,
                title: nil,
                date: nil,
                daysAway: nil,
                ordinal: nil,
                isPremium: false
            )
        }
        let provider = AutoDatesProvider(calendar: calendar)
        let autoDates = provider.autoDates(
            space: context.space,
            members: context.partner.map { [$0] } ?? [],
            people: [],
            now: now
        )
        var kind: ImportantDateKind?
        var title: String?
        var date: Date?
        var ordinal: Int?
        switch source {
        case .anniversary:
            let match = autoDates.first { $0.kind == .anniversary }
            kind = .anniversary
            date = match?.date
            ordinal = match?.years
        case .wedding:
            let match = autoDates.first { $0.kind == .wedding }
            kind = .wedding
            date = match?.date
            ordinal = match?.years
        case .partnerBirthday:
            let match = autoDates.first { $0.kind == .memberBirthday }
            kind = .partnerBirthday
            date = match?.date
            title = match?.name
        case let .customEvent(eventId):
            let event = try await controller.repositories.events.event(id: eventId)
            kind = .customEvent
            date = event?.startAt
            title = event?.title
        }
        return CountdownSnapshot(
            kind: kind,
            title: title,
            date: date,
            daysAway: date.flatMap { calendar.daysAway(from: now, to: $0) },
            ordinal: ordinal,
            isPremium: context.isPremium
        )
    }

    public func tasks(now: Date = Date()) async throws -> TasksSnapshot {
        try await tasksSnapshot(now: now) { _ in true }
    }

    public func freeTasks(now: Date = Date()) async throws -> TasksSnapshot {
        try await tasksSnapshot(now: now) { $0.isFree }
    }

    public func partnerWishes(now: Date = Date()) async throws -> PartnerWishesSnapshot {
        guard let context = try await context(now: now) else {
            return PartnerWishesSnapshot(items: [], remaining: 0, partnerName: nil, isPremium: false)
        }
        guard let partner = context.partner else {
            return PartnerWishesSnapshot(items: [], remaining: 0, partnerName: nil, isPremium: context.isPremium)
        }
        let wishes = try await controller.repositories.wishes.wishes(
            WishQuery(spaceId: context.space.id, owner: .member(partner.id), fulfilled: false)
        )
        let ordered = wishes.sorted { lhs, rhs in
            let left = priorityRank(lhs.priority)
            let right = priorityRank(rhs.priority)
            if left != right { return left < right }
            return (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
        }
        return PartnerWishesSnapshot(
            items: ordered.prefix(WidgetDataProvider.wishLimit).map { wish in
                WidgetWish(
                    id: wish.id,
                    title: wish.title,
                    priceText: Money.make(amount: wish.price, currency: wish.currency)?.formatted(locale: locale),
                    imageURL: wish.imageURL
                )
            },
            remaining: max(0, ordered.count - WidgetDataProvider.wishLimit),
            partnerName: partner.displayName,
            isPremium: context.isPremium
        )
    }

    public func planProgress(planId: UUID? = nil, now: Date = Date()) async throws -> PlanProgressSnapshot {
        guard let context = try await context(now: now) else {
            return planSnapshot(nil, isPremium: false)
        }
        let plans = try await controller.repositories.plans.plans(spaceId: context.space.id, statuses: [.active])
        let plan = planId.flatMap { id in plans.first { $0.id == id } } ?? plans.first
        return planSnapshot(plan, isPremium: context.isPremium)
    }

    public func upcomingDates(now: Date = Date()) async throws -> UpcomingDatesSnapshot {
        guard let context = try await context(now: now) else {
            return UpcomingDatesSnapshot(items: [], isPremium: false)
        }
        let items = try await widgetDates(context: context, now: now)
        return UpcomingDatesSnapshot(
            items: Array(items.prefix(WidgetDataProvider.dateLimit)),
            isPremium: context.isPremium
        )
    }

    public func shopping(now: Date = Date()) async throws -> ShoppingSnapshot {
        guard let context = try await context(now: now) else {
            return ShoppingSnapshot(listId: nil, title: nil, items: [], remaining: 0, isPremium: false)
        }
        let lists = try await controller.repositories.lists.lists(spaceId: context.space.id)
        guard let pinned = lists.first(where: \.isPinnedShopping) else {
            return ShoppingSnapshot(listId: nil, title: nil, items: [], remaining: 0, isPremium: context.isPremium)
        }
        let items = try await controller.repositories.lists.items(listId: pinned.id)
        let open = items.filter { $0.isChecked == false }
        return ShoppingSnapshot(
            listId: pinned.id,
            title: pinned.title,
            items: open.prefix(WidgetDataProvider.shoppingLimit).map { item in
                WidgetShoppingItem(
                    id: item.id,
                    title: item.title,
                    isChecked: item.isChecked,
                    colorKey: context.colorKey(for: item.addedByMemberId)
                )
            },
            remaining: max(0, open.count - WidgetDataProvider.shoppingLimit),
            isPremium: context.isPremium
        )
    }

    public func capsule(now: Date = Date()) async throws -> CapsuleSnapshot {
        guard let context = try await context(now: now) else {
            return CapsuleSnapshot(
                capsuleId: nil,
                authorName: nil,
                opensAt: nil,
                daysAway: nil,
                isForViewer: false,
                isPremium: false
            )
        }
        let capsules = try await controller.repositories.capsules.capsules(spaceId: context.space.id)
        let pending = capsules
            .filter { $0.openedAt == nil && ($0.opensAt ?? .distantPast) > now }
            .sorted { ($0.opensAt ?? .distantFuture) < ($1.opensAt ?? .distantFuture) }
        guard let next = pending.first else {
            return CapsuleSnapshot(
                capsuleId: nil,
                authorName: nil,
                opensAt: nil,
                daysAway: nil,
                isForViewer: false,
                isPremium: context.isPremium
            )
        }
        return CapsuleSnapshot(
            capsuleId: next.id,
            authorName: context.name(for: next.authorMemberId),
            opensAt: next.opensAt,
            daysAway: next.opensAt.flatMap { calendar.daysAway(from: now, to: $0) },
            isForViewer: next.recipientMemberId == context.viewer?.id,
            isPremium: context.isPremium
        )
    }

    public func question(now: Date = Date()) async throws -> QuestionSnapshot {
        guard let context = try await context(now: now) else { return QuestionSnapshot.blank(isPremium: false) }
        guard let viewer = context.viewer,
              let question = try await controller.repositories.questions.todaysQuestion(
                  spaceId: context.space.id,
                  viewerMemberId: viewer.id,
                  now: now
              ),
              let text = QuestionBank.bundled.entry(id: question.questionId)?.text(for: locale)
        else { return QuestionSnapshot.blank(isPremium: context.isPremium) }
        return QuestionSnapshot(
            text: text,
            viewer: questionMember(viewer, question: question),
            partner: context.partner.map { questionMember($0, question: question) },
            isRevealed: question.isRevealed,
            isPremium: context.isPremium
        )
    }

    public func ourDay(now: Date = Date()) async throws -> OurDaySnapshot {
        guard let context = try await context(now: now) else {
            return OurDaySnapshot(days: nil, tasks: [], events: [], plan: nil, isPremium: false)
        }
        let day = try await TodayFeedProvider(
            repositories: controller.repositories,
            calendar: calendar,
            locale: locale
        ).daySummary(space: context.space, viewerMemberId: context.viewer?.id, now: now)
        return OurDaySnapshot(
            days: day.daysTogether,
            tasks: day.tasksToday
                .prefix(WidgetDataProvider.ourDayLineLimit)
                .compactMap { widgetTask($0, context: context) },
            events: day.eventsToday
                .prefix(WidgetDataProvider.ourDayLineLimit)
                .map { widgetEvent($0, context: context) },
            plan: day.plans.first,
            isPremium: context.isPremium
        )
    }

    public func freeSlots(now: Date = Date()) async throws -> FreeSlotsSnapshot {
        guard let context = try await context(now: now) else {
            return FreeSlotsSnapshot(availability: .notPaired, isPremium: false)
        }
        guard let viewer = context.viewer, let partner = context.partner else {
            return FreeSlotsSnapshot(availability: .notPaired, isPremium: context.isPremium)
        }
        guard let horizon = calendar.date(byAdding: .day, value: BusyWindow.horizonDays, to: now) else {
            return FreeSlotsSnapshot(availability: .noSlots, isPremium: context.isPremium)
        }
        let store = RepositoryBusyIntervalStore(
            repository: controller.repositories.busyIntervals,
            spaceId: context.space.id
        )
        let busy = try await store.intervals(spaceId: context.space.id, from: now, to: horizon)
        let result = FreeSlotEngine(calendar: calendar, locale: locale).result(
            viewer: FreeSlotParticipant(memberId: viewer.id, sharesBusyTimes: viewer.sharesBusyTimes),
            partner: FreeSlotParticipant(memberId: partner.id, sharesBusyTimes: partner.sharesBusyTimes),
            busyRanges: busy,
            from: now,
            to: horizon
        )
        switch result {
        case let .slots(slots):
            let text = WidgetFreeSlotText(locale: locale, calendar: calendar)
            return FreeSlotsSnapshot(
                availability: .slots,
                slots: slots.prefix(WidgetDataProvider.freeSlotLimit).map(text.slot),
                isPremium: context.isPremium
            )
        case .viewerHasNoData:
            return FreeSlotsSnapshot(availability: .viewerNotSharing, isPremium: context.isPremium)
        case .partnerHasNoData:
            return FreeSlotsSnapshot(availability: .partnerNotSharing, isPremium: context.isPremium)
        case .none:
            return FreeSlotsSnapshot(availability: .noSlots, isPremium: context.isPremium)
        }
    }

    public func lockCircular(mode: LockCircularMode, now: Date = Date()) async throws -> LockCircularSnapshot {
        guard let context = try await context(now: now) else {
            return LockCircularSnapshot(mode: mode, value: nil, progress: nil, isPremium: false)
        }
        switch mode {
        case .daysTogether:
            return LockCircularSnapshot(
                mode: mode,
                value: ImportantDates.daysTogether(space: context.space, now: now, calendar: calendar),
                progress: nil,
                isPremium: context.isPremium
            )
        case .planRing:
            let plans = try await controller.repositories.plans.plans(spaceId: context.space.id, statuses: [.active])
            guard let plan = plans.first else {
                return LockCircularSnapshot(mode: mode, value: nil, progress: nil, isPremium: context.isPremium)
            }
            return LockCircularSnapshot(
                mode: mode,
                value: plan.isOpenEnded
                    ? Int(plan.totalSavedAmount.rounded())
                    : Int((plan.progress * 100).rounded()),
                progress: plan.isOpenEnded ? nil : plan.progress,
                isPremium: context.isPremium
            )
        case .countdown:
            let dates = try await widgetDates(context: context, now: now)
            return LockCircularSnapshot(
                mode: mode,
                value: dates.first?.daysAway,
                progress: nil,
                isPremium: context.isPremium
            )
        }
    }

    public func lockRectangular(now: Date = Date()) async throws -> LockRectangularSnapshot {
        guard let context = try await context(now: now) else {
            return LockRectangularSnapshot(
                taskTitle: nil,
                taskId: nil,
                freeCount: 0,
                nextDate: nil,
                isPremium: false
            )
        }
        let open = try await openTasks(spaceId: context.space.id)
        let dates = try await widgetDates(context: context, now: now)
        let next = open.first { $0.isFree == false } ?? open.first
        return LockRectangularSnapshot(
            taskTitle: next?.title,
            taskId: next?.id,
            freeCount: open.filter(\.isFree).count,
            nextDate: dates.first,
            isPremium: context.isPremium
        )
    }

    public func lockInline(now: Date = Date()) async throws -> LockInlineSnapshot {
        guard let context = try await context(now: now) else {
            return LockInlineSnapshot(kind: nil, name: nil, daysAway: nil, isPremium: false)
        }
        let dates = try await widgetDates(context: context, now: now)
        guard let next = dates.first else {
            return LockInlineSnapshot(kind: nil, name: nil, daysAway: nil, isPremium: context.isPremium)
        }
        return LockInlineSnapshot(
            kind: next.kind,
            name: next.title,
            daysAway: next.daysAway,
            isPremium: context.isPremium
        )
    }

    private func resolveViewerId(repositories: Repositories) async throws -> UUID? {
        if let viewerMemberIdOverride { return viewerMemberIdOverride }
        guard let appleUserId = identity.currentAppleUserID else { return nil }
        return try await repositories.members.member(appleUserId: appleUserId)?.id
    }

    private func tasksSnapshot(
        now: Date,
        matching isIncluded: (TaskDTO) -> Bool
    ) async throws -> TasksSnapshot {
        guard let context = try await context(now: now) else {
            return TasksSnapshot(items: [], remaining: 0, isPremium: false)
        }
        let open = try await openTasks(spaceId: context.space.id).filter(isIncluded)
        return TasksSnapshot(
            items: open.prefix(WidgetDataProvider.taskLimit).map { widgetTask($0, context: context) },
            remaining: max(0, open.count - WidgetDataProvider.taskLimit),
            isPremium: context.isPremium
        )
    }

    private func openTasks(spaceId: UUID) async throws -> [TaskDTO] {
        let tasks = try await controller.repositories.tasks.tasks(TaskQuery(spaceId: spaceId))
        return tasks.sorted { lhs, rhs in
            switch (lhs.dueAt, rhs.dueAt) {
            case let (left?, right?):
                return left == right ? lhs.title < rhs.title : left < right
            case (nil, _?):
                return false
            case (_?, nil):
                return true
            case (nil, nil):
                return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
            }
        }
    }

    private func widgetTask(_ task: TaskDTO, context: WidgetContext) -> WidgetTask {
        WidgetTask(
            id: task.id,
            title: task.title,
            colorKey: context.colorKey(for: task.assigneeMemberId),
            isFree: task.isFree,
            dueAt: task.dueAt
        )
    }

    private func widgetTask(_ entry: TodayEntry, context: WidgetContext) -> WidgetTask? {
        guard let task = entry.task else { return nil }
        return WidgetTask(
            id: task.id,
            title: task.title,
            colorKey: context.colorKey(for: task.assigneeMemberId),
            isFree: task.isFree,
            dueAt: task.dueAt
        )
    }

    private func questionMember(_ member: MemberDTO, question: DailyQuestionDTO) -> WidgetQuestionMember {
        WidgetQuestionMember(
            name: member.displayName,
            colorKey: member.colorKey,
            hasAnswered: question.hasAnswered(member.id)
        )
    }

    private func widgetEvent(_ entry: TodayEntry, context: WidgetContext) -> WidgetEvent {
        WidgetEvent(
            id: entry.id,
            title: entry.title,
            startAt: entry.startAt,
            isAllDay: entry.isAllDay,
            colorKey: context.colorKey(for: entry.memberId)
        )
    }

    private func widgetDates(context: WidgetContext, now: Date) async throws -> [WidgetDate] {
        let people = try await controller.repositories.people.people(spaceId: context.space.id)
        let dates = try await UpcomingDatesProvider(
            repositories: controller.repositories,
            calendar: calendar
        ).dates(
            space: context.space,
            members: context.members,
            people: people,
            viewerMemberId: context.viewer?.id,
            now: now,
            eventsFrom: calendar.startOfDay(for: now)
        )
        return dates.map { date in
            WidgetDate(
                id: date.id,
                kind: date.kind,
                title: date.name,
                date: date.date,
                daysAway: date.daysAway,
                ordinal: date.ordinal,
                colorKey: context.colorKey(for: date.memberId),
                eventId: date.eventId,
                radar: date.radar
            )
        }
    }

    private func planSnapshot(_ plan: PlanDTO?, isPremium: Bool) -> PlanProgressSnapshot {
        guard let plan else {
            return PlanProgressSnapshot(
                planId: nil,
                title: nil,
                progress: 0,
                savedText: nil,
                targetText: nil,
                isOverspent: false,
                overspentText: nil,
                isPremium: isPremium
            )
        }
        return PlanProgressSnapshot(
            planId: plan.id,
            title: plan.title,
            progress: plan.progress,
            savedText: Money(amount: plan.totalSavedAmount, currency: plan.currency).formatted(locale: locale),
            targetText: Money(amount: plan.targetAmount, currency: plan.currency).formatted(locale: locale),
            isOverspent: plan.isOverspent,
            overspentText: plan.isOverspent
                ? Money(amount: plan.overspentAmount, currency: plan.currency).formatted(locale: locale)
                : nil,
            overspentFraction: plan.overspentFraction,
            isOpenEnded: plan.isOpenEnded,
            expenseCount: plan.expenseCount,
            doneStepCount: plan.doneStepCount,
            stepCount: plan.stepCount,
            isPremium: isPremium
        )
    }

    private func priorityRank(_ priority: WishPriority) -> Int {
        switch priority {
        case .must: return 0
        case .want: return 1
        case .someday: return 2
        }
    }
}

extension WidgetDataProvider {
    public static let optionLimit = 50

    public func selectableEvents(now: Date = Date()) async throws -> [WidgetEventOption] {
        guard let context = try await context(now: now) else { return [] }
        let horizon = calendar.date(byAdding: .day, value: UpcomingDatesProvider.horizonDays, to: now)
        let events = try await controller.repositories.events.events(
            spaceId: context.space.id,
            from: calendar.startOfDay(for: now),
            to: horizon
        )
        return events
            .sorted { ($0.startAt ?? .distantFuture) < ($1.startAt ?? .distantFuture) }
            .prefix(WidgetDataProvider.optionLimit)
            .map { WidgetEventOption(id: $0.id, title: $0.title, date: $0.startAt) }
    }

    public func eventOptions(ids: [UUID], now: Date = Date()) async throws -> [WidgetEventOption] {
        var result: [WidgetEventOption] = []
        for id in ids {
            guard let event = try await controller.repositories.events.event(id: id) else { continue }
            result.append(WidgetEventOption(id: event.id, title: event.title, date: event.startAt))
        }
        return result
    }

    public func selectablePlans(now: Date = Date()) async throws -> [WidgetPlanOption] {
        guard let context = try await context(now: now) else { return [] }
        let plans = try await controller.repositories.plans.plans(
            spaceId: context.space.id,
            statuses: [.active, .completed]
        )
        return plans
            .prefix(WidgetDataProvider.optionLimit)
            .map { WidgetPlanOption(id: $0.id, title: $0.title, progress: $0.progress) }
    }

    public func planOptions(ids: [UUID]) async throws -> [WidgetPlanOption] {
        var result: [WidgetPlanOption] = []
        for id in ids {
            guard let plan = try await controller.repositories.plans.plan(id: id) else { continue }
            result.append(WidgetPlanOption(id: plan.id, title: plan.title, progress: plan.progress))
        }
        return result
    }
}
