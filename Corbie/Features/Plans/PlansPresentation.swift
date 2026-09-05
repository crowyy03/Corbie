import CorbieCore
import Foundation

struct PlanTotals: Equatable {
    let currency: String
    let target: Double
    let saved: Double
    let spent: Double
    let left: Double
    let overspend: Double
    let progress: Double
    let overspendFraction: Double

    init(plan: PlanDTO) {
        currency = plan.currency
        target = plan.targetAmount
        saved = plan.savedAmount
        spent = plan.spentAmount
        left = plan.leftAmount
        overspend = plan.overspentAmount
        progress = plan.progress
        overspendFraction = plan.targetAmount > 0 ? plan.overspentAmount / plan.targetAmount : 0
    }

    var isOverspent: Bool { overspend > 0 }

    func money(_ amount: Double) -> Money {
        Money(amount: amount, currency: currency)
    }

    func savedOfTarget(locale: Locale = .current) -> String {
        String(
            format: String(localized: "plans.card.progress"),
            money(saved).formatted(locale: locale),
            money(target).formatted(locale: locale)
        )
    }

    func overspendBadge(locale: Locale = .current) -> String {
        String(format: String(localized: "plans.card.overspend"), money(overspend).formatted(locale: locale))
    }
}

extension PlanType {
    var systemImage: String {
        switch self {
        case .trip: "airplane"
        case .purchase: "bag"
        case .renovation: "hammer"
        case .event: "calendar"
        case .other: "flag"
        }
    }

    var titleKey: String { "plans.type." + rawValue }
}

extension PlanStatus {
    var titleKey: String { "plans.status." + rawValue }
}

extension ListTemplate {
    var systemImage: String {
        switch self {
        case .places: "mappin.and.ellipse"
        case .watch: "play.rectangle"
        case .cook: "fork.knife"
        case .cities: "building.2"
        case .shopping: "cart"
        case .empty: "list.bullet"
        }
    }

    var titleKey: String { "lists.template." + rawValue }

    var hintKey: String { "lists.template." + rawValue + ".hint" }
}

enum PlansDestination: Equatable {
    case big
    case plan(UUID)
}

enum PlansRoute {
    static func destination(for route: Route?) -> PlansDestination? {
        switch route {
        case .plans: .big
        case let .plan(identifier): .plan(identifier)
        case .tasks, .calendar, .wishes, .capsules, .votes, .join, .none: nil
        }
    }
}

struct PlanReference: Hashable {
    let id: UUID
}

struct ChecklistReference: Hashable {
    let id: UUID
}

func planDateRange(start: Date?, end: Date?, locale: Locale = .current) -> String? {
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
