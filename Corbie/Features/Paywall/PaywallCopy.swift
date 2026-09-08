import CorbieCore
import Foundation

struct PaywallValueRow: Identifiable, Equatable {
    let id: String
    let systemImage: String
    let textKey: String

    static let all: [PaywallValueRow] = [
        PaywallValueRow(id: "calendar", systemImage: "calendar", textKey: "paywall.value.calendar"),
        PaywallValueRow(id: "tasks", systemImage: "checkmark.circle", textKey: "paywall.value.tasks"),
        PaywallValueRow(id: "wishes", systemImage: "star", textKey: "paywall.value.wishes"),
        PaywallValueRow(id: "plans", systemImage: "flag", textKey: "paywall.value.plans"),
        PaywallValueRow(id: "question", systemImage: "bubble.left.and.bubble.right", textKey: "paywall.value.question"),
        PaywallValueRow(id: "widgets", systemImage: "square.grid.2x2", textKey: "paywall.value.widgets")
    ]
}

struct ComparisonRow: Identifiable, Equatable {
    let id: String
    let freeKey: String?
    let premiumKey: String

    static let all: [ComparisonRow] = [
        ComparisonRow(
            id: "calendar",
            freeKey: "paywall.compare.free.calendar",
            premiumKey: "paywall.compare.premium.everything"
        ),
        ComparisonRow(
            id: "today",
            freeKey: "paywall.compare.free.today",
            premiumKey: "paywall.compare.premium.question"
        ),
        ComparisonRow(
            id: "recap",
            freeKey: "paywall.compare.free.recap",
            premiumKey: "paywall.compare.premium.wishes"
        ),
        ComparisonRow(
            id: "made",
            freeKey: "paywall.compare.free.made",
            premiumKey: "paywall.compare.premium.plans"
        ),
        ComparisonRow(id: "capsules", freeKey: nil, premiumKey: "paywall.compare.premium.capsules"),
        ComparisonRow(id: "chores", freeKey: nil, premiumKey: "paywall.compare.premium.chores"),
        ComparisonRow(id: "widgets", freeKey: nil, premiumKey: "paywall.compare.premium.widgets")
    ]
}

enum PaywallCopy {
    static func reasonKey(_ reason: PaywallReason) -> String {
        switch reason {
        case .trialEnding: return "paywall.reason.trialending"
        case .trialEnded: return "paywall.reason.trialended"
        case .settings: return "paywall.reason.settings"
        case .create: return "paywall.reason.create"
        case .edit: return "paywall.reason.edit"
        case .widgets: return "paywall.reason.widgets"
        case .capsules: return "paywall.reason.capsules"
        case .votes: return "paywall.reason.votes"
        case .people: return "paywall.reason.people"
        case .freeTime: return "paywall.reason.freetime"
        }
    }

    static func titleKey(_ product: CorbieProduct) -> String {
        switch product {
        case .monthly: return "paywall.offer.monthly"
        case .yearly: return "paywall.offer.yearly"
        }
    }

    static func legalKey(_ product: CorbieProduct) -> String {
        switch product {
        case .monthly: return "paywall.legal.monthly"
        case .yearly: return "paywall.legal.yearly"
        }
    }

    static func text(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    static func reasonText(_ reason: PaywallReason) -> String {
        text(reasonKey(reason))
    }

    static func headerKey(_ reason: PaywallReason) -> String {
        reason == .trialEnded ? "paywall.compare.expired" : "paywall.headline"
    }

    static func legalText(for offer: SubscriptionOffer) -> String {
        String(format: text(legalKey(offer.product)), offer.displayPrice)
    }

    static func callToAction(for offer: SubscriptionOffer?) -> String {
        guard let days = offer?.eligibleFreeTrialDays else { return text("paywall.cta.subscribe") }
        return String.localizedStringWithFormat(text("paywall.cta.trial"), days)
    }

    static func savingsBadge(for offer: SubscriptionOffer) -> String? {
        guard let percent = offer.savingsPercent else { return nil }
        return String.localizedStringWithFormat(text("paywall.offer.badge"), percent)
    }

    static func monthlyEquivalent(for offer: SubscriptionOffer) -> String? {
        guard let style = offer.priceFormatStyle,
              let amount = SubscriptionOfferMath.monthlyEquivalent(offer)
        else { return nil }
        return String(format: text("paywall.offer.permonth"), amount.formatted(style))
    }

    static func yearAtMonthlyPrice(for offer: SubscriptionOffer, monthly: SubscriptionOffer?) -> String? {
        guard offer.product == .yearly, offer.savingsPercent != nil else { return nil }
        guard let monthly, monthly.price > 0, let style = offer.priceFormatStyle else { return nil }
        return SubscriptionOfferMath.twelveMonths(of: monthly.price).formatted(style)
    }
}
