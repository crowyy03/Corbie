#if DEBUG
import Foundation

public enum DebugEntitlementOverride: String, Sendable, Equatable, CaseIterable, Codable {
    case premium
    case trialEnding = "trial_ending"
    case readOnly = "read_only"
    case trialEnded = "trial_ended"
    case subscriptionEnded = "subscription_ended"
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
        case .readOnly, .trialEnded, .subscriptionEnded:
            return .readOnly
        case .gracePeriod:
            return .grace(expiresAt: now.addingTimeInterval(Double(DebugEntitlementOverride.gracePeriodDays) * 86_400))
        case .introOfferUsed:
            return nil
        }
    }

    public var readOnlyCause: ReadOnlyCause? {
        switch self {
        case .trialEnded: return .trialEnded
        case .subscriptionEnded: return .subscriptionEnded
        case .premium, .trialEnding, .readOnly, .introOfferUsed, .gracePeriod: return nil
        }
    }

    public var hidesIntroOffer: Bool { self == .introOfferUsed }

    private static func defaults(_ suiteName: String) -> UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}

public enum DebugMonetizationOverride: String, Sendable, Equatable, CaseIterable, Codable {
    case on
    case off

    public static let storageKey = "corbie.debug.monetization"

    public var isEnabled: Bool { self == .on }

    public static func stored(suiteName: String = CorbieIdentifiers.appGroup) -> DebugMonetizationOverride? {
        guard let raw = defaults(suiteName).string(forKey: storageKey) else { return nil }
        return DebugMonetizationOverride(rawValue: raw)
    }

    public static func store(_ override: DebugMonetizationOverride?, suiteName: String = CorbieIdentifiers.appGroup) {
        guard let override else {
            defaults(suiteName).removeObject(forKey: storageKey)
            return
        }
        defaults(suiteName).set(override.rawValue, forKey: storageKey)
    }

    private static func defaults(_ suiteName: String) -> UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
#endif
