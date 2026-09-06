import Foundation

public enum TodayBlock: String, Sendable, Equatable, CaseIterable {
    case today
    case freeTasks = "free_tasks"
    case comingUp = "coming_up"
    case goal
    case waiting
    case recap
}

public enum TodayQuickAction: String, Sendable, Equatable, CaseIterable, Identifiable {
    case task
    case date
    case invite

    public var id: String { rawValue }
}

public enum TodayEntryItem: Sendable, Equatable {
    case event(EventDTO)
    case task(UnifiedTask)
}

public struct TodayEntry: Sendable, Equatable, Identifiable {
    public let item: TodayEntryItem
    public let goalId: UUID?
    public let isAllDay: Bool

    public init(event: EventDTO) {
        item = .event(event)
        goalId = nil
        isAllDay = event.isAllDay
    }

    public init(task: UnifiedTask, goalId: UUID?, calendar: Calendar) {
        item = .task(task)
        self.goalId = goalId
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

    public var goalTitle: String? {
        switch item {
        case .event: return nil
        case let .task(task): return task.goalTitle
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

public struct TodayDate: Sendable, Equatable, Identifiable {
    public static let radarHorizonDays = RadarService.horizonDays

    public let id: String
    public let kind: AutoDateKind
    public let name: String?
    public let date: Date
    public let daysAway: Int
    public let ordinal: Int?
    public let memberId: UUID?
    public let personId: UUID?
    public let eventId: UUID?
    public let radar: RadarStatus?

    public init(
        id: String,
        kind: AutoDateKind,
        name: String?,
        date: Date,
        daysAway: Int,
        ordinal: Int? = nil,
        memberId: UUID? = nil,
        personId: UUID? = nil,
        eventId: UUID? = nil,
        radar: RadarStatus? = nil
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.date = date
        self.daysAway = daysAway
        self.ordinal = ordinal
        self.memberId = memberId
        self.personId = personId
        self.eventId = eventId
        self.radar = radar
    }

    public var isGiftMissing: Bool {
        guard let radar, radar.giftPicked == false else { return false }
        guard daysAway <= TodayDate.radarHorizonDays else { return false }
        switch kind {
        case .anniversary, .wedding, .memberBirthday, .personBirthday:
            return true
        case .event:
            return false
        }
    }

    public var ideasCount: Int { radar?.ideasCount ?? 0 }
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

public struct TodayFeed: Sendable, Equatable {
    public static let freeTaskLimit = 3
    public static let comingUpLimit = 3

    public let day: Date
    public let daysTogether: Int?
    public let entries: [TodayEntry]
    public let freeTasks: [UnifiedTask]
    public let freeTasksRemaining: Int
    public let comingUp: [TodayDate]
    public let goal: GoalDTO?
    public let waiting: [TodayWaitingItem]
    public let recap: RecapSummary?
    public let isPaired: Bool

    public init(
        day: Date,
        daysTogether: Int? = nil,
        entries: [TodayEntry] = [],
        freeTasks: [UnifiedTask] = [],
        freeTasksRemaining: Int = 0,
        comingUp: [TodayDate] = [],
        goal: GoalDTO? = nil,
        waiting: [TodayWaitingItem] = [],
        recap: RecapSummary? = nil,
        isPaired: Bool = false
    ) {
        self.day = day
        self.daysTogether = daysTogether
        self.entries = entries
        self.freeTasks = freeTasks
        self.freeTasksRemaining = freeTasksRemaining
        self.comingUp = comingUp
        self.goal = goal
        self.waiting = waiting
        self.recap = recap
        self.isPaired = isPaired
    }

    public var isEmpty: Bool {
        entries.isEmpty
            && freeTasks.isEmpty
            && comingUp.isEmpty
            && goal == nil
            && waiting.isEmpty
            && recap == nil
    }

    public var blocks: [TodayBlock] {
        var result: [TodayBlock] = []
        if entries.isEmpty == false { result.append(.today) }
        if freeTasks.isEmpty == false { result.append(.freeTasks) }
        if comingUp.isEmpty == false { result.append(.comingUp) }
        if goal != nil { result.append(.goal) }
        if waiting.isEmpty == false { result.append(.waiting) }
        if recap != nil { result.append(.recap) }
        return result
    }
}
