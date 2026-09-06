import Foundation

public enum TodayBlock: String, Sendable, Equatable, CaseIterable {
    case plans
    case tasks
    case events
    case freeTasks = "free_tasks"
    case comingUp = "coming_up"
    case waiting
    case recap
}

public enum TodayQuickAction: String, Sendable, Equatable, CaseIterable, Identifiable {
    case task
    case date
    case plan
    case invite

    public var id: String { rawValue }
}

public struct TodayPlan: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let type: PlanType
    public let progress: Double
    public let savedText: String
    public let targetText: String
    public let doneStepCount: Int
    public let stepCount: Int

    public init(
        id: UUID,
        title: String,
        type: PlanType,
        progress: Double,
        savedText: String,
        targetText: String,
        doneStepCount: Int,
        stepCount: Int
    ) {
        self.id = id
        self.title = title
        self.type = type
        self.progress = progress
        self.savedText = savedText
        self.targetText = targetText
        self.doneStepCount = doneStepCount
        self.stepCount = stepCount
    }

    public init(_ plan: PlanDTO, locale: Locale = .current) {
        self.init(
            id: plan.id,
            title: plan.title,
            type: plan.type,
            progress: plan.progress,
            savedText: Money(amount: plan.totalSavedAmount, currency: plan.currency).formatted(locale: locale),
            targetText: Money(amount: plan.targetAmount, currency: plan.currency).formatted(locale: locale),
            doneStepCount: plan.doneStepCount,
            stepCount: plan.stepCount
        )
    }
}

public enum TodayEntryItem: Sendable, Equatable {
    case event(EventDTO)
    case task(UnifiedTask)
}

public struct TodayEntry: Sendable, Equatable, Identifiable {
    public let item: TodayEntryItem
    public let planId: UUID?
    public let isAllDay: Bool

    public init(event: EventDTO) {
        item = .event(event)
        planId = nil
        isAllDay = event.isAllDay
    }

    public init(task: UnifiedTask, planId: UUID?, calendar: Calendar) {
        item = .task(task)
        self.planId = planId
        guard let dueAt = task.dueAt else {
            isAllDay = true
            return
        }
        isAllDay = calendar.startOfDay(for: dueAt) == dueAt
    }

    public var id: UUID {
        switch item {
        case let .event(event): return event.id
        case let .task(task): return task.id
        }
    }

    public var title: String {
        switch item {
        case let .event(event): return event.title
        case let .task(task): return task.title
        }
    }

    public var startAt: Date? {
        switch item {
        case let .event(event): return event.startAt
        case let .task(task): return task.dueAt
        }
    }

    public var memberId: UUID? {
        switch item {
        case let .event(event): return event.createdByMemberId
        case let .task(task): return task.assigneeMemberId
        }
    }

    public var isDone: Bool {
        switch item {
        case .event: return false
        case let .task(task): return task.isDone
        }
    }

    public var planTitle: String? {
        switch item {
        case .event: return nil
        case let .task(task): return task.planTitle
        }
    }

    public var task: UnifiedTask? {
        switch item {
        case .event: return nil
        case let .task(task): return task
        }
    }

    public static func ordered(_ entries: [TodayEntry]) -> [TodayEntry] {
        entries.sorted { lhs, rhs in
            if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
            let left = lhs.startAt ?? .distantFuture
            let right = rhs.startAt ?? .distantFuture
            if left != right { return left < right }
            if lhs.title != rhs.title { return lhs.title < rhs.title }
            return lhs.id.uuidString < rhs.id.uuidString
        }
    }
}

public enum TodayWaitingItem: Sendable, Equatable, Identifiable {
    case capsule(CapsuleDTO)
    case vote(VoteDTO)
    case partnerWishes(count: Int)

    public var id: String {
        switch self {
        case let .capsule(capsule): return "capsule." + capsule.id.uuidString
        case let .vote(vote): return "vote." + vote.id.uuidString
        case .partnerWishes: return "wishes"
        }
    }
}

public struct TodayDaySummary: Sendable, Equatable {
    public let day: Date
    public let daysTogether: Int?
    public let plans: [TodayPlan]
    public let tasksToday: [TodayEntry]
    public let eventsToday: [TodayEntry]

    public init(
        day: Date,
        daysTogether: Int? = nil,
        plans: [TodayPlan] = [],
        tasksToday: [TodayEntry] = [],
        eventsToday: [TodayEntry] = []
    ) {
        self.day = day
        self.daysTogether = daysTogether
        self.plans = plans
        self.tasksToday = tasksToday
        self.eventsToday = eventsToday
    }
}

public struct TodayFeed: Sendable, Equatable {
    public static let freeTaskLimit = 3
    public static let comingUpLimit = 3

    public let day: Date
    public let daysTogether: Int?
    public let plans: [TodayPlan]
    public let tasksToday: [TodayEntry]
    public let eventsToday: [TodayEntry]
    public let freeTasks: [UnifiedTask]
    public let freeTasksRemaining: Int
    public let comingUp: [UpcomingDate]
    public let waiting: [TodayWaitingItem]
    public let recap: RecapSummary?
    public let isPaired: Bool

    public init(
        day: Date,
        daysTogether: Int? = nil,
        plans: [TodayPlan] = [],
        tasksToday: [TodayEntry] = [],
        eventsToday: [TodayEntry] = [],
        freeTasks: [UnifiedTask] = [],
        freeTasksRemaining: Int = 0,
        comingUp: [UpcomingDate] = [],
        waiting: [TodayWaitingItem] = [],
        recap: RecapSummary? = nil,
        isPaired: Bool = false
    ) {
        self.day = day
        self.daysTogether = daysTogether
        self.plans = plans
        self.tasksToday = tasksToday
        self.eventsToday = eventsToday
        self.freeTasks = freeTasks
        self.freeTasksRemaining = freeTasksRemaining
        self.comingUp = comingUp
        self.waiting = waiting
        self.recap = recap
        self.isPaired = isPaired
    }

    public var isEmpty: Bool {
        plans.isEmpty
            && tasksToday.isEmpty
            && eventsToday.isEmpty
            && freeTasks.isEmpty
            && comingUp.isEmpty
            && waiting.isEmpty
            && recap == nil
    }

    public var blocks: [TodayBlock] {
        var result: [TodayBlock] = []
        if plans.isEmpty == false { result.append(.plans) }
        if tasksToday.isEmpty == false { result.append(.tasks) }
        if eventsToday.isEmpty == false { result.append(.events) }
        if freeTasks.isEmpty == false { result.append(.freeTasks) }
        if comingUp.isEmpty == false { result.append(.comingUp) }
        if waiting.isEmpty == false { result.append(.waiting) }
        if recap != nil { result.append(.recap) }
        return result
    }
}
