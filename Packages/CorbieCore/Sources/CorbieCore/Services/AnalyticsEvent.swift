import Foundation

public enum AnalyticsAssignee: String, Sendable, Equatable, CaseIterable, Codable {
    case nobody
    case me
    case partner
}

public enum AnalyticsEvent: Sendable, Equatable {
    case appOpen
    case onboardingStep(Int)
    case spaceCreated
    case inviteCreated
    case inviteRedeemed
    case taskCreated(assignee: AnalyticsAssignee)
    case taskTaken
    case taskDone
    case eventCreated(kind: EventKind)
    case wishCreated(source: WishSource)
    case planCreated(type: PlanType)
    case expenseAdded
    case listCreated(template: ListTemplate)
    case capsuleCreated
    case capsuleOpened
    case voteCreated
    case voteAnswered
    case voteRevealed
    case widgetAdded(kind: String)
    case paywallShown(reason: PaywallReason)
    case trialStarted
    case purchase(product: String)
    case restore
    case readonlyHit(action: PremiumAction)

    public var name: String {
        switch self {
        case .appOpen: return "app_open"
        case .onboardingStep: return "onboarding_step"
        case .spaceCreated: return "space_created"
        case .inviteCreated: return "invite_created"
        case .inviteRedeemed: return "invite_redeemed"
        case .taskCreated: return "task_created"
        case .taskTaken: return "task_taken"
        case .taskDone: return "task_done"
        case .eventCreated: return "event_created"
        case .wishCreated: return "wish_created"
        case .planCreated: return "plan_created"
        case .expenseAdded: return "expense_added"
        case .listCreated: return "list_created"
        case .capsuleCreated: return "capsule_created"
        case .capsuleOpened: return "capsule_opened"
        case .voteCreated: return "vote_created"
        case .voteAnswered: return "vote_answered"
        case .voteRevealed: return "vote_revealed"
        case .widgetAdded: return "widget_added"
        case .paywallShown: return "paywall_shown"
        case .trialStarted: return "trial_started"
        case .purchase: return "purchase"
        case .restore: return "restore"
        case .readonlyHit: return "readonly_hit"
        }
    }

    public var props: [String: AnalyticsValue] {
        switch self {
        case let .onboardingStep(step):
            return ["step": .number(Double(step))]
        case let .taskCreated(assignee):
            return ["assignee": .string(assignee.rawValue)]
        case let .eventCreated(kind):
            return ["kind": .string(kind.rawValue)]
        case let .wishCreated(source):
            return ["source": .string(source.rawValue)]
        case let .planCreated(type):
            return ["type": .string(type.rawValue)]
        case let .listCreated(template):
            return ["template": .string(template.rawValue)]
        case let .widgetAdded(kind):
            return ["kind": .string(AnalyticsEvent.slug(kind))]
        case let .paywallShown(reason):
            return ["reason": .string(reason.rawValue)]
        case let .purchase(product):
            return ["product": .string(AnalyticsEvent.slug(product))]
        case let .readonlyHit(action):
            return ["action": .string(action.rawValue)]
        case .appOpen, .spaceCreated, .inviteCreated, .inviteRedeemed, .taskTaken, .taskDone,
             .expenseAdded, .capsuleCreated, .capsuleOpened, .voteCreated, .voteAnswered, .voteRevealed,
             .trialStarted, .restore:
            return [:]
        }
    }

    public static let allowedNames: Set<String> = [
        "app_open", "onboarding_step", "space_created", "invite_created", "invite_redeemed",
        "task_created", "task_taken", "task_done", "event_created", "wish_created",
        "plan_created", "expense_added", "list_created", "capsule_created", "capsule_opened",
        "vote_created", "vote_revealed", "widget_added", "paywall_shown", "trial_started",
        "purchase", "restore", "readonly_hit"
    ]

    public static let droppedPropKeys: Set<String> = [
        "email", "name", "phone", "title", "body", "text", "url"
    ]

    static func slug(_ raw: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789._-")
        let mapped = raw.lowercased().map { allowed.contains($0) ? $0 : "_" }
        return String(mapped.prefix(40))
    }
}
