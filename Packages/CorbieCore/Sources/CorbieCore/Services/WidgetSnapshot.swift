import Foundation

public enum CountdownSource: Sendable, Codable, Equatable, Hashable {
    case anniversary
    case wedding
    case partnerBirthday
    case customEvent(UUID)
}

public enum LockCircularMode: String, Sendable, Codable, Equatable, CaseIterable {
    case daysTogether
    case planRing
    case countdown
}

public enum WidgetDateKind: String, Sendable, Codable, Equatable, CaseIterable {
    case anniversary
    case wedding
    case memberBirthday
    case personBirthday
    case event

    public init(_ kind: AutoDateKind) {
        switch kind {
        case .anniversary: self = .anniversary
        case .wedding: self = .wedding
        case .memberBirthday: self = .memberBirthday
        case .personBirthday: self = .personBirthday
        case .event: self = .event
        }
    }
}

public struct WidgetTask: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let colorKey: String?
    public let isFree: Bool
    public let dueAt: Date?

    public init(id: UUID, title: String, colorKey: String?, isFree: Bool, dueAt: Date?) {
        self.id = id
        self.title = title
        self.colorKey = colorKey
        self.isFree = isFree
        self.dueAt = dueAt
    }
}

public struct WidgetWish: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let priceText: String?
    public let imageURL: String?

    public init(id: UUID, title: String, priceText: String?, imageURL: String?) {
        self.id = id
        self.title = title
        self.priceText = priceText
        self.imageURL = imageURL
    }
}

public struct WidgetShoppingItem: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let isChecked: Bool
    public let colorKey: String?

    public init(id: UUID, title: String, isChecked: Bool, colorKey: String?) {
        self.id = id
        self.title = title
        self.isChecked = isChecked
        self.colorKey = colorKey
    }
}

public struct WidgetDate: Sendable, Codable, Equatable, Identifiable {
    public let id: String
    public let kind: WidgetDateKind
    public let title: String?
    public let date: Date
    public let daysAway: Int
    public let ordinal: Int?
    public let colorKey: String?
    public let eventId: UUID?
    public let radar: RadarStatus?

    public init(
        id: String,
        kind: WidgetDateKind,
        title: String?,
        date: Date,
        daysAway: Int,
        ordinal: Int? = nil,
        colorKey: String? = nil,
        eventId: UUID? = nil,
        radar: RadarStatus? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.date = date
        self.daysAway = daysAway
        self.ordinal = ordinal
        self.colorKey = colorKey
        self.eventId = eventId
        self.radar = radar
    }
}

public struct DaysTogetherSnapshot: Sendable, Codable, Equatable {
    public let days: Int?
    public let isPremium: Bool

    public init(days: Int?, isPremium: Bool) {
        self.days = days
        self.isPremium = isPremium
    }
}

public struct CountdownSnapshot: Sendable, Codable, Equatable {
    public let kind: ImportantDateKind?
    public let title: String?
    public let date: Date?
    public let daysAway: Int?
    public let ordinal: Int?
    public let isPremium: Bool

    public init(
        kind: ImportantDateKind?,
        title: String?,
        date: Date?,
        daysAway: Int?,
        ordinal: Int?,
        isPremium: Bool
    ) {
        self.kind = kind
        self.title = title
        self.date = date
        self.daysAway = daysAway
        self.ordinal = ordinal
        self.isPremium = isPremium
    }
}

public struct TasksSnapshot: Sendable, Codable, Equatable {
    public let items: [WidgetTask]
    public let remaining: Int
    public let isPremium: Bool

    public init(items: [WidgetTask], remaining: Int, isPremium: Bool) {
        self.items = items
        self.remaining = remaining
        self.isPremium = isPremium
    }
}

public struct FreeTasksSnapshot: Sendable, Codable, Equatable {
    public let items: [WidgetTask]
    public let remaining: Int
    public let isPremium: Bool

    public init(items: [WidgetTask], remaining: Int, isPremium: Bool) {
        self.items = items
        self.remaining = remaining
        self.isPremium = isPremium
    }
}

public struct PartnerWishesSnapshot: Sendable, Codable, Equatable {
    public let items: [WidgetWish]
    public let remaining: Int
    public let partnerName: String?
    public let isPremium: Bool

    public init(items: [WidgetWish], remaining: Int, partnerName: String?, isPremium: Bool) {
        self.items = items
        self.remaining = remaining
        self.partnerName = partnerName
        self.isPremium = isPremium
    }
}

public struct PlanProgressSnapshot: Sendable, Codable, Equatable {
    public let planId: UUID?
    public let title: String?
    public let progress: Double
    public let savedText: String?
    public let targetText: String?
    public let isOverspent: Bool
    public let overspentText: String?
    public let isPremium: Bool

    public init(
        planId: UUID?,
        title: String?,
        progress: Double,
        savedText: String?,
        targetText: String?,
        isOverspent: Bool,
        overspentText: String?,
        isPremium: Bool
    ) {
        self.planId = planId
        self.title = title
        self.progress = progress
        self.savedText = savedText
        self.targetText = targetText
        self.isOverspent = isOverspent
        self.overspentText = overspentText
        self.isPremium = isPremium
    }
}

public struct UpcomingDatesSnapshot: Sendable, Codable, Equatable {
    public let items: [WidgetDate]
    public let isPremium: Bool

    public init(items: [WidgetDate], isPremium: Bool) {
        self.items = items
        self.isPremium = isPremium
    }
}

public struct ShoppingSnapshot: Sendable, Codable, Equatable {
    public let listId: UUID?
    public let title: String?
    public let items: [WidgetShoppingItem]
    public let remaining: Int
    public let isPremium: Bool

    public init(listId: UUID?, title: String?, items: [WidgetShoppingItem], remaining: Int, isPremium: Bool) {
        self.listId = listId
        self.title = title
        self.items = items
        self.remaining = remaining
        self.isPremium = isPremium
    }
}

public struct CapsuleSnapshot: Sendable, Codable, Equatable {
    public let capsuleId: UUID?
    public let authorName: String?
    public let opensAt: Date?
    public let daysAway: Int?
    public let isForViewer: Bool
    public let isPremium: Bool

    public init(
        capsuleId: UUID?,
        authorName: String?,
        opensAt: Date?,
        daysAway: Int?,
        isForViewer: Bool,
        isPremium: Bool
    ) {
        self.capsuleId = capsuleId
        self.authorName = authorName
        self.opensAt = opensAt
        self.daysAway = daysAway
        self.isForViewer = isForViewer
        self.isPremium = isPremium
    }
}

public struct OurDaySnapshot: Sendable, Codable, Equatable {
    public let days: Int?
    public let nextDate: WidgetDate?
    public let plan: PlanProgressSnapshot?
    public let tasks: [WidgetTask]
    public let isPremium: Bool

    public init(
        days: Int?,
        nextDate: WidgetDate?,
        plan: PlanProgressSnapshot?,
        tasks: [WidgetTask],
        isPremium: Bool
    ) {
        self.days = days
        self.nextDate = nextDate
        self.plan = plan
        self.tasks = tasks
        self.isPremium = isPremium
    }
}

public struct LockCircularSnapshot: Sendable, Codable, Equatable {
    public let mode: LockCircularMode
    public let value: Int?
    public let progress: Double?
    public let isPremium: Bool

    public init(mode: LockCircularMode, value: Int?, progress: Double?, isPremium: Bool) {
        self.mode = mode
        self.value = value
        self.progress = progress
        self.isPremium = isPremium
    }
}

public struct LockRectangularSnapshot: Sendable, Codable, Equatable {
    public let taskTitle: String?
    public let taskId: UUID?
    public let freeCount: Int
    public let nextDate: WidgetDate?
    public let isPremium: Bool

    public init(taskTitle: String?, taskId: UUID?, freeCount: Int, nextDate: WidgetDate?, isPremium: Bool) {
        self.taskTitle = taskTitle
        self.taskId = taskId
        self.freeCount = freeCount
        self.nextDate = nextDate
        self.isPremium = isPremium
    }
}

public struct LockInlineSnapshot: Sendable, Codable, Equatable {
    public let kind: WidgetDateKind?
    public let name: String?
    public let daysAway: Int?
    public let isPremium: Bool

    public init(kind: WidgetDateKind?, name: String?, daysAway: Int?, isPremium: Bool) {
        self.kind = kind
        self.name = name
        self.daysAway = daysAway
        self.isPremium = isPremium
    }
}

public enum WidgetPremiumRule {
    public static func isPremium(space: SpaceDTO, now: Date) -> Bool {
        if space.trialActive(at: now) { return true }
        guard space.subscriptionStatus == .active else { return false }
        guard let expiresAt = space.subscriptionExpiresAt else { return true }
        return expiresAt > now
    }
}

public struct WidgetEventOption: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let date: Date?

    public init(id: UUID, title: String, date: Date?) {
        self.id = id
        self.title = title
        self.date = date
    }
}

public struct WidgetPlanOption: Sendable, Codable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let progress: Double

    public init(id: UUID, title: String, progress: Double) {
        self.id = id
        self.title = title
        self.progress = progress
    }
}
