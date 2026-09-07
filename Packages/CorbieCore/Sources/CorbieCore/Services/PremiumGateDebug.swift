#if DEBUG
import Foundation

public enum DebugEntitlementOverride: String, Sendable, Equatable, CaseIterable, Codable {
    case premium
    case trialEnding = "trial_ending"
    case readOnly = "read_only"
    case introOfferUsed = "intro_offer_used"
    case gracePeriod = "grace_period"

    public static let storageKey = "corbie.debug.entitlement"
    public static let gracePeriodDays = 3

    public static func stored(suiteName: String = CorbieIdentifiers.appGroup) -> DebugEntitlementOverride? {
        guard let raw = DebugEntitlementOverride.defaults(suiteName).string(forKey: storageKey) else { return nil }
        return DebugEntitlementOverride(rawValue: raw)
    }

    public static func store(_ override: DebugEntitlementOverride?, suiteName: String = CorbieIdentifiers.appGroup) {
        let defaults = DebugEntitlementOverride.defaults(suiteName)
        guard let override else {
            defaults.removeObject(forKey: storageKey)
            return
        }
        defaults.set(override.rawValue, forKey: storageKey)
    }

    public func state(now: Date) -> EntitlementState? {
        switch self {
        case .premium:
            return .premium(source: .storeKit, expiresAt: nil)
        case .trialEnding:
            let endsAt = now.addingTimeInterval(Double(PremiumGate.trialNoticeDays) * 86_400)
            return .trial(daysLeft: PremiumGate.trialNoticeDays, endsAt: endsAt)
        case .readOnly:
            return .readOnly
        case .gracePeriod:
            return .grace(expiresAt: now.addingTimeInterval(Double(DebugEntitlementOverride.gracePeriodDays) * 86_400))
        case .introOfferUsed:
            return nil
        }
    }

    public var hidesIntroOffer: Bool { self == .introOfferUsed }

    private static func defaults(_ suiteName: String) -> UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
#endif
