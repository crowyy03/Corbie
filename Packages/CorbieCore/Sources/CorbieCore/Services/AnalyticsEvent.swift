import Foundation

public enum AnalyticsAssignee: String, Sendable, Equatable, CaseIterable, Codable {
    case nobody
    case me
    case partner
}

public enum PurchaseFailureReason: String, Sendable, Equatable, CaseIterable, Codable {
    case unavailable
    case unverified
    case noSpace = "no_space"
    case storeError = "store_error"
}

public enum FreeTimeEmptyReason: String, Sendable, Equatable, CaseIterable, Codable {
    case notPaired = "not_paired"
    case viewerNotSharing = "viewer_not_sharing"
    case partnerNotSharing = "partner_not_sharing"
    case calendarDenied = "calendar_denied"
    case noSlots = "no_slots"
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
    case taskHandedBack
    case eventCreated(kind: EventKind)
    case wishCreated(source: WishSource)
    case wishFulfilled
    case planCreated(type: PlanType, isOpenEnded: Bool)
    case planCompleted
    case planStepCreated(hasDue: Bool)
    case planStepDone
    case expenseAdded(isNegative: Bool)
    case listCreated(template: ListTemplate)
    case listItemChecked
    case listMapOpened
    case freetimeOpened
    case freetimeSharingEnabled
    case freetimeSharingDisabled
    case freetimeSlotTapped
    case freetimeEmpty(reason: FreeTimeEmptyReason)
    case capsuleCreated
    case capsuleOpened
    case voteCreated
    case voteAnswered
    case voteRevealed
    case questionShown
    case questionAnswered
    case questionRevealed
    case questionNudgeSent
    case questionHistoryOpened
    case choreFlowStarted
    case choreListBuilt(itemCount: Int, customCount: Int)
    case choreRatingDone
    case choreRevealed(tradeCount: Int, rotateCount: Int)
    case choreApplied(taskCount: Int)
    case choreResplit
    case todayOpened
    case todayBlockTapped(block: TodayBlock)
    case todayQuickAction(kind: TodayQuickAction)
    case recapShown
    case recapNotificationSent
    case recapOpened
    case widgetAdded(kind: String)
    case trialOfferShown
    case trialStarted(product: CorbieProduct)
    case comparisonShown(reason: PaywallReason)
    case planSelected(product: CorbieProduct)
    case purchaseStarted(product: CorbieProduct)
    case purchaseCompleted(product: CorbieProduct, isTrial: Bool)
    case purchaseFailed(reason: PurchaseFailureReason)
    case restoreTapped
    case readonlyHit(feature: PremiumAction)
    case paywallDismissed(screen: PaywallScreen)
    case gracePeriodEntered

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
        case .taskHandedBack: return "task_handed_back"
        case .eventCreated: return "event_created"
        case .wishCreated: return "wish_created"
        case .wishFulfilled: return "wish_fulfilled"
        case .planCreated: return "plan_created"
        case .planCompleted: return "plan_completed"
        case .planStepCreated: return "plan_step_created"
        case .planStepDone: return "plan_step_done"
        case .expenseAdded: return "expense_added"
        case .listCreated: return "list_created"
        case .listItemChecked: return "list_item_checked"
        case .listMapOpened: return "list_map_opened"
        case .freetimeOpened: return "freetime_opened"
        case .freetimeSharingEnabled: return "freetime_sharing_enabled"
        case .freetimeSharingDisabled: return "freetime_sharing_disabled"
        case .freetimeSlotTapped: return "freetime_slot_tapped"
        case .freetimeEmpty: return "freetime_empty"
        case .capsuleCreated: return "capsule_created"
        case .capsuleOpened: return "capsule_opened"
        case .voteCreated: return "vote_created"
        case .voteAnswered: return "vote_answered"
        case .voteRevealed: return "vote_revealed"
        case .questionShown: return "question_shown"
        case .questionAnswered: return "question_answered"
        case .questionRevealed: return "question_revealed"
        case .questionNudgeSent: return "question_nudge_sent"
        case .questionHistoryOpened: return "question_history_opened"
        case .choreFlowStarted: return "chore_flow_started"
        case .choreListBuilt: return "chore_list_built"
        case .choreRatingDone: return "chore_rating_done"
        case .choreRevealed: return "chore_revealed"
        case .choreApplied: return "chore_applied"
        case .choreResplit: return "chore_resplit"
        case .todayOpened: return "today_opened"
        case .todayBlockTapped: return "today_block_tapped"
        case .todayQuickAction: return "today_quick_action"
        case .recapShown: return "recap_shown"
        case .recapNotificationSent: return "recap_notification_sent"
        case .recapOpened: return "recap_opened"
        case .widgetAdded: return "widget_added"
        case .trialOfferShown: return "trial_offer_shown"
        case .trialStarted: return "trial_started"
        case .comparisonShown: return "comparison_shown"
        case .planSelected: return "plan_selected"
        case .purchaseStarted: return "purchase_started"
        case .purchaseCompleted: return "purchase_completed"
        case .purchaseFailed: return "purchase_failed"
        case .restoreTapped: return "restore_tapped"
        case .readonlyHit: return "readonly_hit"
        case .paywallDismissed: return "paywall_dismissed"
        case .gracePeriodEntered: return "grace_period_entered"
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
        case let .planCreated(type, isOpenEnded):
            return ["type": .string(type.rawValue), "is_open_ended": .flag(isOpenEnded)]
        case let .expenseAdded(isNegative):
            return ["is_negative": .flag(isNegative)]
        case let .choreListBuilt(itemCount, customCount):
            return ["item_count": .number(Double(itemCount)), "custom_count": .number(Double(customCount))]
        case let .choreRevealed(tradeCount, rotateCount):
            return ["trade_count": .number(Double(tradeCount)), "rotate_count": .number(Double(rotateCount))]
        case let .choreApplied(taskCount):
            return ["task_count": .number(Double(taskCount))]
        case let .planStepCreated(hasDue):
            return ["has_due": .flag(hasDue)]
        case let .listCreated(template):
            return ["template": .string(template.rawValue)]
        case let .todayBlockTapped(block):
            return ["block": .string(block.rawValue)]
        case let .todayQuickAction(kind):
            return ["kind": .string(kind.rawValue)]
        case let .freetimeEmpty(reason):
            return ["reason": .string(reason.rawValue)]
        case let .widgetAdded(kind):
            return ["kind": .string(AnalyticsEvent.slug(kind))]
        case let .comparisonShown(reason):
            return ["reason": .string(reason.rawValue)]
        case let .trialStarted(product), let .planSelected(product), let .purchaseStarted(product):
            return ["product": .string(product.identifier)]
        case let .purchaseCompleted(product, isTrial):
            return ["product": .string(product.identifier), "is_trial": .flag(isTrial)]
        case let .purchaseFailed(reason):
            return ["reason": .string(reason.rawValue)]
        case let .readonlyHit(feature):
            return ["feature": .string(feature.rawValue)]
        case let .paywallDismissed(screen):
            return ["screen": .string(screen.rawValue)]
        case .appOpen, .spaceCreated, .inviteCreated, .inviteRedeemed, .taskTaken, .taskDone,
             .taskHandedBack, .wishFulfilled, .planCompleted, .planStepDone,
             .listItemChecked, .listMapOpened, .freetimeOpened, .freetimeSharingEnabled,
             .freetimeSharingDisabled, .freetimeSlotTapped, .capsuleCreated, .capsuleOpened,
             .voteCreated, .voteAnswered, .voteRevealed, .questionShown, .questionAnswered,
             .questionRevealed, .questionNudgeSent, .questionHistoryOpened, .choreFlowStarted,
             .choreRatingDone, .choreResplit, .todayOpened, .recapShown,
             .recapNotificationSent, .recapOpened, .trialOfferShown, .restoreTapped,
             .gracePeriodEntered:
            return [:]
        }
    }

    public static let allowedNames: Set<String> = [
        "app_open", "onboarding_step", "space_created", "invite_created", "invite_redeemed",
        "task_created", "task_taken", "task_done", "event_created", "wish_created", "wish_fulfilled",
        "plan_created", "plan_completed", "plan_step_created", "plan_step_done", "expense_added",
        "list_created", "list_item_checked", "list_map_opened",
        "freetime_opened", "freetime_sharing_enabled",
        "freetime_sharing_disabled", "freetime_slot_tapped", "freetime_empty",
        "capsule_created", "capsule_opened", "vote_created",
        "vote_answered", "vote_revealed", "widget_added",
        "trial_offer_shown", "trial_started", "comparison_shown", "plan_selected",
        "purchase_started", "purchase_completed", "purchase_failed", "restore_tapped",
        "readonly_hit", "paywall_dismissed", "grace_period_entered",
        "task_handed_back", "today_opened",
        "today_block_tapped", "today_quick_action", "recap_shown", "recap_notification_sent",
        "recap_opened", "question_shown", "question_answered", "question_revealed",
        "question_nudge_sent", "question_history_opened", "chore_flow_started",
        "chore_list_built", "chore_rating_done", "chore_revealed", "chore_applied",
        "chore_resplit"
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
