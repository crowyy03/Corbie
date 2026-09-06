import CorbieCore
import Foundation

struct GoalTotals: Equatable {
    let currency: String
    let target: Double
    let saved: Double
    let added: Double
    let left: Double
    let overspend: Double
    let progress: Double
    let overspendFraction: Double

    init(goal: GoalDTO) {
        currency = goal.currency
        target = goal.targetAmount
        saved = goal.totalSavedAmount
        added = goal.addedAmount
        left = goal.leftAmount
        overspend = goal.overspentAmount
        progress = goal.progress
        overspendFraction = goal.targetAmount > 0 ? goal.overspentAmount / goal.targetAmount : 0
    }

    var isOverspent: Bool { overspend > 0 }

    func money(_ amount: Double) -> Money {
        Money(amount: amount, currency: currency)
    }

    func savedOfTarget(locale: Locale = .current) -> String {
        String(
            format: String(localized: "goals.card.progress"),
            money(saved).formatted(locale: locale),
            money(target).formatted(locale: locale)
        )
    }

    func overspendBadge(locale: Locale = .current) -> String {
        String(format: String(localized: "goals.card.overspend"), money(overspend).formatted(locale: locale))
    }
}

extension GoalType {
    var systemImage: String {
        switch self {
        case .trip: "airplane"
        case .purchase: "bag"
        case .renovation: "hammer"
        case .event: "calendar"
        case .other: "flag"
        }
    }

    var titleKey: String { "goals.type." + rawValue }
}

extension GoalStatus {
    var titleKey: String { "goals.status." + rawValue }
}

enum GoalsDestination: Equatable {
    case list
    case goal(UUID)
}

enum GoalsRoute {
    static func destination(for route: Route?) -> GoalsDestination? {
        switch route {
        case .goals: .list
        case let .goal(identifier): .goal(identifier)
        case .tasks, .task, .calendar, .wishes, .capsules, .votes, .people, .person, .join, .none: nil
        }
    }
}

struct GoalReference: Hashable {
    let id: UUID
}

func goalDateRange(start: Date?, end: Date?, locale: Locale = .current) -> String? {
    let day = Date.FormatStyle.dateTime.day().month(.abbreviated).year().locale(locale)
    switch (start, end) {
    case let (start?, end?) where end > start:
        return (start..<end).formatted(.interval.day().month(.abbreviated).year().locale(locale))
    case let (start?, _):
        return start.formatted(day)
    case let (_, end?):
        return end.formatted(day)
    default:
        return nil
    }
}
