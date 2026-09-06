import Foundation

public struct RecapWeek: Sendable, Equatable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }
}

public struct RecapWindow: Sendable, Equatable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public enum RecapSchedule {
    public static let notificationHour = 19
    public static let cardEndHour = 9
    public static let milestones = [100, 365, 500, 1000]

    private static let gregorianSunday = DateComponents(year: 2026, month: 1, day: 4, hour: 12)

    public static func sundayWeekday(in calendar: Calendar) -> Int {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        guard let sunday = gregorian.date(from: gregorianSunday) else { return 1 }
        return calendar.component(.weekday, from: sunday)
    }

    public static func week(endingOn day: Date, calendar: Calendar) -> RecapWeek {
        let lastDay = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
        let start = calendar.date(byAdding: .day, value: -6, to: lastDay) ?? lastDay
        return RecapWeek(start: start, end: end)
    }

    public static func week(closing now: Date, calendar: Calendar) -> RecapWeek {
        week(endingOn: latestSunday(onOrBefore: now, calendar: calendar), calendar: calendar)
    }

    public static func nextNotificationDate(after now: Date, calendar: Calendar) -> Date? {
        calendar.nextDate(
            after: now,
            matching: DateComponents(
                hour: notificationHour,
                minute: 0,
                second: 0,
                weekday: sundayWeekday(in: calendar)
            ),
            matchingPolicy: .nextTime
        )
    }

    public static func window(containing now: Date, calendar: Calendar) -> RecapWindow? {
        let sunday = latestSunday(onOrBefore: now, calendar: calendar)
        guard let start = calendar.date(bySettingHour: notificationHour, minute: 0, second: 0, of: sunday),
              let monday = calendar.date(byAdding: .day, value: 1, to: sunday),
              let end = calendar.date(bySettingHour: cardEndHour, minute: 0, second: 0, of: monday),
              now >= start,
              now < end else { return nil }
        return RecapWindow(start: start, end: end)
    }

    public static func isCardVisible(now: Date, lastSeenAt: Date?, calendar: Calendar) -> Bool {
        guard let window = window(containing: now, calendar: calendar) else { return false }
        guard let lastSeenAt else { return true }
        return lastSeenAt < window.start
    }

    public static func latestSunday(onOrBefore date: Date, calendar: Calendar) -> Date {
        let weekday = sundayWeekday(in: calendar)
        let today = calendar.startOfDay(for: date)
        for offset in 0...6 {
            guard let candidate = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            if calendar.component(.weekday, from: candidate) == weekday { return candidate }
        }
        return today
    }
}

public struct RecapMemberTally: Sendable, Equatable, Identifiable {
    public let memberId: UUID
    public let name: String?
    public let colorKey: String?
    public let tasksDone: Int
    public let wishesAdded: Int

    public init(memberId: UUID, name: String?, colorKey: String?, tasksDone: Int, wishesAdded: Int) {
        self.memberId = memberId
        self.name = name
        self.colorKey = colorKey
        self.tasksDone = tasksDone
        self.wishesAdded = wishesAdded
    }

    public var id: UUID { memberId }
}

public struct RecapGoalMove: Sendable, Equatable, Identifiable {
    public let goalId: UUID
    public let title: String
    public let delta: Double
    public let currency: String
    public let progress: Double

    public init(goalId: UUID, title: String, delta: Double, currency: String, progress: Double) {
        self.goalId = goalId
        self.title = title
        self.delta = delta
        self.currency = currency
        self.progress = progress
    }

    public var id: UUID { goalId }
}

public struct RecapUpcoming: Sendable, Equatable, Identifiable {
    public let id: String
    public let kind: AutoDateKind
    public let name: String?
    public let date: Date
    public let eventId: UUID?

    public init(id: String, kind: AutoDateKind, name: String?, date: Date, eventId: UUID? = nil) {
        self.id = id
        self.kind = kind
        self.name = name
        self.date = date
        self.eventId = eventId
    }
}

public struct RecapMilestone: Sendable, Equatable {
    public let days: Int
    public let date: Date

    public init(days: Int, date: Date) {
        self.days = days
        self.date = date
    }
}

public struct RecapSummary: Sendable, Equatable {
    public static let goalLimit = 2
    public static let upcomingLimit = 3

    public let week: RecapWeek
    public let members: [RecapMemberTally]
    public let goals: [RecapGoalMove]
    public let comingUp: [RecapUpcoming]
    public let daysTogether: Int?
    public let milestone: RecapMilestone?

    public init(
        week: RecapWeek,
        members: [RecapMemberTally] = [],
        goals: [RecapGoalMove] = [],
        comingUp: [RecapUpcoming] = [],
        daysTogether: Int? = nil,
        milestone: RecapMilestone? = nil
    ) {
        self.week = week
        self.members = members
        self.goals = goals
        self.comingUp = comingUp
        self.daysTogether = daysTogether
        self.milestone = milestone
    }

    public var hasActivity: Bool {
        members.contains { $0.tasksDone > 0 || $0.wishesAdded > 0 } || goals.isEmpty == false
    }

    public var isPaired: Bool { members.count >= 2 }
}
