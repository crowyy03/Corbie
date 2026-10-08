import CorbieCore
import Foundation

struct SettingsSubscriptionStatus: Equatable {
    let state: EntitlementState
    var now = Date()

    var text: String {
        if let endsAt = state.freeWindowEndsAt {
            return FreeWindowCopy.line(endsAt: endsAt, now: now)
        }
        switch state {
        case let .trial(daysLeft, _):
            return String.localizedStringWithFormat(String(localized: "settings.subscription.trial"), daysLeft)
        case let .premium(_, expiresAt):
            guard let expiresAt else { return String(localized: "settings.subscription.active") }
            return String.localizedStringWithFormat(
                String(localized: "settings.subscription.active.until"),
                expiresAt.formatted(date: .abbreviated, time: .omitted)
            )
        case let .grace(expiresAt):
            guard let expiresAt else { return String(localized: "settings.subscription.grace") }
            return String.localizedStringWithFormat(
                String(localized: "settings.subscription.grace.until"),
                expiresAt.formatted(date: .abbreviated, time: .omitted)
            )
        case .readOnly:
            return String(localized: "settings.subscription.readonly")
        }
    }

    var showsPlans: Bool {
        guard state.freeWindowEndsAt == nil else { return false }
        return state.isPremium == false || state.trialDaysLeft != nil
    }
}

enum SettingsAccountPlan: Equatable {
    case deleteSpace
    case leaveSpace

    static func decide(space: SpaceDTO, memberId: UUID?) -> SettingsAccountPlan {
        guard let creator = space.creatorMemberId else { return .deleteSpace }
        guard let memberId else { return .leaveSpace }
        return creator == memberId ? .deleteSpace : .leaveSpace
    }

    static func offersLeaving(space: SpaceDTO?, memberId: UUID?) -> Bool {
        guard let space, let memberId else { return false }
        return decide(space: space, memberId: memberId) == .leaveSpace
    }
}
