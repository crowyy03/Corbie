import CorbieCore
import Foundation

struct PaywallValueRow: Identifiable, Equatable {
    let id: String
    let systemImage: String
    let titleKey: String
    let noteKey: String

    static let all: [PaywallValueRow] = [
        PaywallValueRow(
            id: "widgets",
            systemImage: "square.grid.2x2",
            titleKey: "paywall.value.widgets.title",
            noteKey: "paywall.value.widgets.note"
        ),
        PaywallValueRow(
            id: "goals",
            systemImage: "flag",
            titleKey: "paywall.value.goals.title",
            noteKey: "paywall.value.goals.note"
        ),
        PaywallValueRow(
            id: "capsules",
            systemImage: "envelope",
            titleKey: "paywall.value.capsules.title",
            noteKey: "paywall.value.capsules.note"
        )
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
        case .folders: return "paywall.reason.folders"
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

    static func legalText(for offer: SubscriptionOffer) -> String {
        String(format: text(legalKey(offer.product)), offer.displayPrice)
    }

    static func savingsBadge(for offer: SubscriptionOffer) -> String? {
        guard let percent = offer.savingsPercent else { return nil }
        return String(format: text("paywall.offer.badge"), percent)
    }

    static func monthlyEquivalent(for offer: SubscriptionOffer, locale: Locale = .current) -> String? {
        guard let currency = offer.currencyCode,
              let amount = SubscriptionOfferMath.monthlyEquivalent(offer)
        else { return nil }
        let money = Money(amount: amount, currency: currency).formatted(locale: locale)
        return String(format: text("paywall.offer.permonth"), money)
    }
}
