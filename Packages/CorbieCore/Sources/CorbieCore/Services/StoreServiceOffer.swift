import Foundation

public enum CorbieProduct: String, Sendable, Equatable, CaseIterable, Codable {
    case monthly
    case yearly

    public var monthsPerPeriod: Int {
        switch self {
        case .monthly: return 1
        case .yearly: return 12
        }
    }
}

public struct StoreProductIdentifiers: Sendable, Equatable {
    public static let monthlyInfoKey = "CORBIE_MONTHLY_PRODUCT_ID"
    public static let yearlyInfoKey = "CORBIE_YEARLY_PRODUCT_ID"

    private let byProduct: [CorbieProduct: String]

    public init(monthly: String, yearly: String) {
        self.init(byProduct: [.monthly: monthly, .yearly: yearly])
    }

    public init(bundle: Bundle) {
        self.init(byProduct: [
            .monthly: bundle.object(forInfoDictionaryKey: StoreProductIdentifiers.monthlyInfoKey) as? String,
            .yearly: bundle.object(forInfoDictionaryKey: StoreProductIdentifiers.yearlyInfoKey) as? String
        ].compactMapValues { $0 })
    }

    private init(byProduct: [CorbieProduct: String]) {
        self.byProduct = byProduct
            .mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.value.isEmpty == false }
    }

    public var all: [String] {
        CorbieProduct.allCases.compactMap { byProduct[$0] }
    }

    public func identifier(for product: CorbieProduct) -> String? {
        byProduct[product]
    }

    public func product(for identifier: String) -> CorbieProduct? {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        return byProduct.first { $0.value == trimmed }?.key
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
    public let productId: String
    public let displayPrice: String
    public let price: Decimal
    public let priceFormatStyle: Decimal.FormatStyle.Currency?
    public let savingsPercent: Int?
    public let eligibleFreeTrialDays: Int?

    public init(
        product: CorbieProduct,
        productId: String,
        displayPrice: String,
        price: Decimal,
        priceFormatStyle: Decimal.FormatStyle.Currency? = nil,
        savingsPercent: Int? = nil,
        eligibleFreeTrialDays: Int? = nil
    ) {
        self.product = product
        self.productId = productId
        self.displayPrice = displayPrice
        self.price = price
        self.priceFormatStyle = priceFormatStyle
        self.savingsPercent = savingsPercent
        self.eligibleFreeTrialDays = eligibleFreeTrialDays
    }

    public var id: String { productId }

    public func withSavings(_ percent: Int?) -> SubscriptionOffer {
        SubscriptionOffer(
            product: product,
            productId: productId,
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
    case success(signedTransaction: String)
    case pending
    case cancelled
}

public enum RestoreOutcome: Sendable, Equatable {
    case restored
    case nothingToRestore
}
