import CorbieCore
import Foundation

struct PlanTotals: Equatable {
    let currency: String
    let target: Double
    let saved: Double
    let added: Double
    let left: Double
    let overspend: Double
    let progress: Double
    let overspendFraction: Double

    init(plan: PlanDTO) {
        currency = plan.currency
        target = plan.targetAmount
        saved = plan.totalSavedAmount
        added = plan.addedAmount
        left = plan.leftAmount
        overspend = plan.overspentAmount
        progress = plan.progress
        overspendFraction = plan.overspentFraction
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
    case lists
    case list(UUID)
}

enum PlansRoute {
    static func destination(for route: Route?) -> PlansDestination? {
        switch route {
        case .plans: .big
        case let .plan(identifier): .plan(identifier)
        case .lists: .lists
        case let .list(identifier): .list(identifier)
        case .today, .tasks, .task, .calendar, .wishes, .capsules, .votes, .people, .person, .us, .question,
             .join, .paywall, .none:
            nil
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

struct PlanStepDue: Equatable {
    let text: String
    let isOverdue: Bool
}

func planStepsBadge(done: Int, total: Int, locale: Locale = .current) -> String? {
    guard total > 0 else { return nil }
    return String(
        format: String(localized: "plans.card.steps"),
        done.formatted(.number.locale(locale)),
        total.formatted(.number.locale(locale))
    )
}

func planContributions(count: Int) -> String {
    String.localizedStringWithFormat(String(localized: "plans.card.contributions"), count)
}

func planOpenSubtitle(startedAt: Date?, contributionCount: Int, locale: Locale = .current) -> String {
    let contributions = planContributions(count: contributionCount)
    guard let startedAt else { return contributions }
    return String.localizedStringWithFormat(
        String(localized: "plans.card.open.since"),
        startedAt.formatted(.dateTime.month(.wide).year().locale(locale)),
        contributions
    )
}

func planStepDue(
    for step: PlanStepDTO,
    now: Date,
    locale: Locale = .current,
    calendar: Calendar = .current
) -> PlanStepDue? {
    guard let dueAt = step.dueAt else { return nil }
    let dates = RelativeDateText(locale: locale, calendar: calendar)
    let isOverdue = step.isDone == false && (dates.calendar.daysAway(from: now, to: dueAt) ?? 0) < 0
    let format = isOverdue
        ? String(localized: "plans.step.due.past")
        : String(localized: "plans.step.due")
    return PlanStepDue(
        text: String(format: format, dates.dueText(for: dueAt, now: now)),
        isOverdue: isOverdue
    )
}

func planStepOrder(_ steps: [PlanStepDTO], moving offsets: IndexSet, to destination: Int) -> [UUID] {
    var ids = steps.map(\.id)
    ids.move(fromOffsets: offsets, toOffset: destination)
    return ids
}
