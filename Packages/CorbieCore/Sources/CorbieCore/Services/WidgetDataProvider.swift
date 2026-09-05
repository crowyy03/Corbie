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
    public static let wishLimit = 3
    public static let dateLimit = 3
    public static let shoppingLimit = 5
    public static let upcomingHorizonDays = 400

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
        guard let space = try await repositories.spaces.firstSpace() else { return nil }
        let members = try await repositories.members.members(spaceId: space.id)
        let viewerId = resolveViewerId(members: members)
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
                source: source,
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
            source: source,
            kind: kind,
            title: title,
            date: date,
            daysAway: date.flatMap { provider.daysAway(from: now, to: $0) },
            ordinal: ordinal,
            isPremium: context.isPremium
        )
    }

    public func tasks(now: Date = Date()) async throws -> TasksSnapshot {
        guard let context = try await context(now: now) else {
            return TasksSnapshot(items: [], remaining: 0, isPremium: false)
        }
        let open = try await openTasks(spaceId: context.space.id)
        return TasksSnapshot(
            items: open.prefix(WidgetDataProvider.taskLimit).map { widgetTask($0, context: context) },
            remaining: max(0, open.count - WidgetDataProvider.taskLimit),
            isPremium: context.isPremium
        )
    }

    public func freeTasks(now: Date = Date()) async throws -> FreeTasksSnapshot {
        guard let context = try await context(now: now) else {
            return FreeTasksSnapshot(items: [], remaining: 0, isPremium: false)
        }
        let free = try await openTasks(spaceId: context.space.id).filter(\.isFree)
        return FreeTasksSnapshot(
            items: free.prefix(WidgetDataProvider.taskLimit).map { widgetTask($0, context: context) },
            remaining: max(0, free.count - WidgetDataProvider.taskLimit),
            isPremium: context.isPremium
        )
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
                    priceText: WidgetAmountText.string(amount: wish.price, currency: wish.currency, locale: locale),
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
            return emptyPlan(isPremium: false)
        }
        let plans = try await controller.repositories.plans.plans(spaceId: context.space.id, statuses: [.active])
        let plan = planId.flatMap { id in plans.first { $0.id == id } } ?? plans.first
        guard let plan else { return emptyPlan(isPremium: context.isPremium) }
        return PlanProgressSnapshot(
            planId: plan.id,
            title: plan.title,
            progress: plan.progress,
            savedText: WidgetAmountText.string(amount: plan.savedAmount, currency: plan.currency, locale: locale),
            targetText: WidgetAmountText.string(amount: plan.targetAmount, currency: plan.currency, locale: locale),
            isOverspent: plan.isOverspent,
            overspentText: plan.isOverspent
                ? WidgetAmountText.string(amount: plan.overspentAmount, currency: plan.currency, locale: locale)
                : nil,
            isPremium: context.isPremium
        )
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
        let provider = AutoDatesProvider(calendar: calendar)
        return CapsuleSnapshot(
            capsuleId: next.id,
            authorName: context.name(for: next.authorMemberId),
            opensAt: next.opensAt,
            daysAway: next.opensAt.flatMap { provider.daysAway(from: now, to: $0) },
            isForViewer: next.recipientMemberId == context.viewer?.id,
            isPremium: context.isPremium
        )
    }

    public func ourDay(now: Date = Date()) async throws -> OurDaySnapshot {
        guard let context = try await context(now: now) else {
            return OurDaySnapshot(days: nil, nextDate: nil, plan: nil, tasks: [], isPremium: false)
        }
        let open = try await openTasks(spaceId: context.space.id)
        let dates = try await widgetDates(context: context, now: now)
        let plans = try await controller.repositories.plans.plans(spaceId: context.space.id, statuses: [.active])
        let plan = plans.first
        return OurDaySnapshot(
            days: ImportantDates.daysTogether(space: context.space, now: now, calendar: calendar),
            nextDate: dates.first,
            plan: plan.map { value in
                PlanProgressSnapshot(
                    planId: value.id,
                    title: value.title,
                    progress: value.progress,
                    savedText: WidgetAmountText.string(
                        amount: value.savedAmount,
                        currency: value.currency,
                        locale: locale
                    ),
                    targetText: WidgetAmountText.string(
                        amount: value.targetAmount,
                        currency: value.currency,
                        locale: locale
                    ),
                    isOverspent: value.isOverspent,
                    overspentText: value.isOverspent
                        ? WidgetAmountText.string(
                            amount: value.overspentAmount,
                            currency: value.currency,
                            locale: locale
                        )
                        : nil,
                    isPremium: context.isPremium
                )
            },
            tasks: open.prefix(WidgetDataProvider.taskLimit).map { widgetTask($0, context: context) },
            isPremium: context.isPremium
        )
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
            return LockCircularSnapshot(
                mode: mode,
                value: plans.first.map { Int(($0.progress * 100).rounded()) },
                progress: plans.first?.progress,
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

    private func resolveViewerId(members: [MemberDTO]) -> UUID? {
        if let viewerMemberIdOverride { return viewerMemberIdOverride }
        guard let appleUserId = identity.currentAppleUserID else { return members.first?.id }
        let hash = AppleUserHash.value(appleUserId)
        return members.first { $0.appleUserHash == hash }?.id ?? members.first?.id
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

    private func widgetDates(context: WidgetContext, now: Date) async throws -> [WidgetDate] {
        let provider = AutoDatesProvider(calendar: calendar)
        let people = try await controller.repositories.people.people(spaceId: context.space.id)
        let autoDates = provider.upcoming(
            space: context.space,
            members: context.members,
            people: people,
            now: now,
            within: WidgetDataProvider.upcomingHorizonDays
        )
        let radar = RadarService(calendar: calendar)
        let partnerWishes: [WishDTO]
        if let partner = context.partner {
            partnerWishes = try await controller.repositories.wishes.wishes(
                WishQuery(spaceId: context.space.id, owner: .member(partner.id), fulfilled: nil)
            )
        } else {
            partnerWishes = []
        }
        let input = RadarInput(
            space: context.space,
            members: context.members,
            people: people,
            partnerWishes: partnerWishes,
            viewerMemberId: context.viewer?.id
        )
        var items: [WidgetDate] = autoDates.compactMap { autoDate in
            guard let daysAway = provider.daysAway(from: now, to: autoDate.date) else { return nil }
            return WidgetDate(
                id: autoDate.id,
                kind: WidgetDateKind(autoDate.kind),
                title: autoDate.name,
                date: autoDate.date,
                daysAway: daysAway,
                ordinal: autoDate.years,
                colorKey: context.colorKey(for: autoDate.ownerMemberId),
                radar: daysAway <= RadarService.horizonDays
                    ? radar.radarLine(for: autoDate, input: input, now: now)?.status
                    : nil
            )
        }
        let horizon = calendar.date(
            byAdding: .day,
            value: WidgetDataProvider.upcomingHorizonDays,
            to: now
        )
        let events = try await controller.repositories.events.events(
            spaceId: context.space.id,
            from: calendar.startOfDay(for: now),
            to: horizon
        )
        for event in events {
            guard let startAt = event.startAt,
                  let daysAway = provider.daysAway(from: now, to: startAt),
                  daysAway >= 0 else { continue }
            items.append(
                WidgetDate(
                    id: "event." + event.id.uuidString,
                    kind: .event,
                    title: event.title,
                    date: startAt,
                    daysAway: daysAway,
                    colorKey: context.colorKey(for: event.createdByMemberId),
                    eventId: event.id
                )
            )
        }
        return items.sorted { lhs, rhs in
            lhs.date == rhs.date ? lhs.id < rhs.id : lhs.date < rhs.date
        }
    }

    private func emptyPlan(isPremium: Bool) -> PlanProgressSnapshot {
        PlanProgressSnapshot(
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

    private func priorityRank(_ priority: WishPriority) -> Int {
        switch priority {
        case .must: return 0
        case .want: return 1
        case .someday: return 2
        }
    }
}
