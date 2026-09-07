import CorbieCore
import Foundation

struct SettingsSubscriptionStatus: Equatable {
    let state: EntitlementState

    var text: String {
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

    var showsPlans: Bool { state.isPremium == false || state.trialDaysLeft != nil }
}

enum SettingsAccountPlan: Equatable {
    case deleteSpace
    case leaveSpace

    static func decide(space: SpaceDTO, memberId: UUID?) -> SettingsAccountPlan {
        guard let creator = space.creatorMemberId else { return .deleteSpace }
        guard let memberId else { return .leaveSpace }
        return creator == memberId ? .deleteSpace : .leaveSpace
    }
}
