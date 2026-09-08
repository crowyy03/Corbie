import Foundation

public enum CorbieProduct: String, Sendable, Equatable, CaseIterable, Codable {
    case monthly = "app.corbie.monthly"
    case yearly = "app.corbie.yearly"

    public static let identifiers = CorbieProduct.allCases.map(\.rawValue)

    public init?(identifier: String) {
        self.init(rawValue: identifier.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public var identifier: String { rawValue }

    public var monthsPerPeriod: Int {
        switch self {
        case .monthly: return 1
        case .yearly: return 12
        }
    }
}

public enum SubscriptionPeriodUnit: String, Sendable, Equatable, CaseIterable, Codable {
    case day
    case week
    case month
    case year

    public var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
}

public enum StoreRenewalState: String, Sendable, Equatable, CaseIterable, Codable {
    case subscribed
    case inGracePeriod = "in_grace_period"
    case inBillingRetry = "in_billing_retry"
    case expired
    case revoked
}

public struct SubscriptionOffer: Sendable, Equatable, Identifiable {
    public let product: CorbieProduct
    public let displayPrice: String
    public let price: Decimal
    public let priceFormatStyle: Decimal.FormatStyle.Currency?
    public let savingsPercent: Int?
    public let eligibleFreeTrialDays: Int?

    public init(
        product: CorbieProduct,
        displayPrice: String,
        price: Decimal,
        priceFormatStyle: Decimal.FormatStyle.Currency? = nil,
        savingsPercent: Int? = nil,
        eligibleFreeTrialDays: Int? = nil
    ) {
        self.product = product
        self.displayPrice = displayPrice
        self.price = price
        self.priceFormatStyle = priceFormatStyle
        self.savingsPercent = savingsPercent
        self.eligibleFreeTrialDays = eligibleFreeTrialDays
    }

    public var id: String { product.rawValue }

    public func withSavings(_ percent: Int?) -> SubscriptionOffer {
        SubscriptionOffer(
            product: product,
            displayPrice: displayPrice,
            price: price,
            priceFormatStyle: priceFormatStyle,
            savingsPercent: percent,
            eligibleFreeTrialDays: eligibleFreeTrialDays
        )
    }
}

public enum SubscriptionOfferMath {
    public static func twelveMonths(of monthly: Decimal) -> Decimal {
        monthly * Decimal(CorbieProduct.yearly.monthsPerPeriod)
    }

    public static func savingsPercent(monthly: Decimal, yearly: Decimal) -> Int? {
        guard monthly > 0, yearly > 0 else { return nil }
        let payingMonthly = twelveMonths(of: monthly)
        guard yearly < payingMonthly else { return nil }
        let saved = (payingMonthly - yearly) / payingMonthly * 100
        let percent = Int(NSDecimalNumber(decimal: saved).doubleValue.rounded())
        return percent > 0 ? percent : nil
    }

    public static func applySavings(to offers: [SubscriptionOffer]) -> [SubscriptionOffer] {
        guard let monthly = offers.first(where: { $0.product == .monthly }),
              offers.contains(where: { $0.product == .yearly })
        else { return offers }
        return offers.map { offer in
            guard offer.product == .yearly else { return offer }
            return offer.withSavings(savingsPercent(monthly: monthly.price, yearly: offer.price))
        }
    }

    public static func monthlyEquivalent(_ offer: SubscriptionOffer) -> Decimal? {
        let months = offer.product.monthsPerPeriod
        guard months > 1, offer.price > 0 else { return nil }
        return offer.price / Decimal(months)
    }

    public static func sorted(_ offers: [SubscriptionOffer]) -> [SubscriptionOffer] {
        offers.sorted { lhs, rhs in
            lhs.product.monthsPerPeriod > rhs.product.monthsPerPeriod
        }
    }

    public static func freeTrialDays(unit: SubscriptionPeriodUnit, value: Int, periodCount: Int) -> Int? {
        let days = unit.days * value * periodCount
        return days > 0 ? days : nil
    }
}

public enum PurchaseOutcome: Sendable, Equatable {
    case success(LocalEntitlement)
    case pending
    case cancelled
}
