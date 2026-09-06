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

public struct SubscriptionOffer: Sendable, Equatable, Identifiable {
    public let product: CorbieProduct
    public let displayPrice: String
    public let price: Decimal
    public let currencyCode: String?
    public let savingsPercent: Int?

    public init(
        product: CorbieProduct,
        displayPrice: String,
        price: Decimal,
        currencyCode: String? = nil,
        savingsPercent: Int? = nil
    ) {
        self.product = product
        self.displayPrice = displayPrice
        self.price = price
        self.currencyCode = currencyCode
        self.savingsPercent = savingsPercent
    }

    public var id: String { product.rawValue }

    public func withSavings(_ percent: Int?) -> SubscriptionOffer {
        SubscriptionOffer(
            product: product,
            displayPrice: displayPrice,
            price: price,
            currencyCode: currencyCode,
            savingsPercent: percent
        )
    }
}

public enum SubscriptionOfferMath {
    public static func savingsPercent(monthly: Decimal, yearly: Decimal) -> Int? {
        guard monthly > 0, yearly > 0 else { return nil }
        let twelveMonths = monthly * 12
        guard yearly < twelveMonths else { return nil }
        let saved = (twelveMonths - yearly) / twelveMonths * 100
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
}

public enum PurchaseOutcome: Sendable, Equatable {
    case success(LocalEntitlement)
    case pending
    case cancelled
}
