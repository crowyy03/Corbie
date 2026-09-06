import Foundation
import StoreKit

public actor StoreService: LocalEntitlementProviding {
    public static let shared = StoreService()

    private var analytics: (any AnalyticsRecording)?
    private var products: [CorbieProduct: Product] = [:]
    private var updates: Task<Void, Never>?

    public init(analytics: (any AnalyticsRecording)? = nil) {
        self.analytics = analytics
    }

    deinit {
        updates?.cancel()
    }

    public func attachAnalytics(_ analytics: any AnalyticsRecording) {
        self.analytics = analytics
    }

    public func loadProducts() async throws -> [CorbieProduct: Product] {
        do {
            let loaded = try await Product.products(for: CorbieProduct.identifiers)
            var mapped: [CorbieProduct: Product] = [:]
            for product in loaded {
                guard let known = CorbieProduct(identifier: product.id) else { continue }
                mapped[known] = product
            }
            products = mapped
            return mapped
        } catch {
            throw CorbieError.network("could not load products: \(error)")
        }
    }

    public func offers() async throws -> [SubscriptionOffer] {
        let loaded = products.isEmpty ? try await loadProducts() : products
        let offers = loaded.map { product, storeProduct in
            SubscriptionOffer(
                product: product,
                displayPrice: storeProduct.displayPrice,
                price: storeProduct.price,
                currencyCode: storeProduct.priceFormatStyle.locale.currency?.identifier
            )
        }
        return SubscriptionOfferMath.sorted(SubscriptionOfferMath.applySavings(to: offers))
    }

    public func purchase(_ product: CorbieProduct, appAccountToken: UUID) async throws -> PurchaseOutcome {
        let loaded = products.isEmpty ? try await loadProducts() : products
        guard let storeProduct = loaded[product] else {
            throw CorbieError.notFound("product \(product.identifier) is not available")
        }
        let result: Product.PurchaseResult
        do {
            result = try await storeProduct.purchase(options: [.appAccountToken(appAccountToken)])
        } catch {
            throw CorbieError.network("purchase failed: \(error)")
        }
        switch result {
        case let .success(verification):
            let transaction = try StoreService.verified(verification)
            await transaction.finish()
            analytics?.record(.purchase(product: product.identifier))
            return .success(StoreService.entitlement(from: transaction))
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    public func restore() async throws {
        do {
            try await AppStore.sync()
        } catch {
            throw CorbieError.network("restore failed: \(error)")
        }
        analytics?.record(.restore)
    }

    public func currentEntitlement() async -> LocalEntitlement? {
        var best: LocalEntitlement?
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? StoreService.verified(result),
                  CorbieProduct(identifier: transaction.productID) != nil
            else { continue }
            let candidate = StoreService.entitlement(from: transaction)
            guard candidate.isRevoked == false else { continue }
            if StoreService.isNewer(candidate, than: best) { best = candidate }
        }
        return best
    }

    public func startListening(onChange: @escaping @Sendable (LocalEntitlement?) async -> Void) {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard let transaction = try? StoreService.verified(update) else { continue }
                await transaction.finish()
                await onChange(await self?.currentEntitlement() ?? nil)
            }
        }
    }

    static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case let .verified(value):
            return value
        case let .unverified(_, error):
            throw CorbieError.auth("app store receipt is not verified: \(error)")
        }
    }

    static func entitlement(from transaction: Transaction) -> LocalEntitlement {
        LocalEntitlement(
            productId: transaction.productID,
            expiresAt: transaction.expirationDate,
            isRevoked: transaction.revocationDate != nil
        )
    }

    static func isNewer(_ candidate: LocalEntitlement, than current: LocalEntitlement?) -> Bool {
        guard let current else { return true }
        guard let candidateExpiry = candidate.expiresAt else { return true }
        guard let currentExpiry = current.expiresAt else { return false }
        return candidateExpiry > currentExpiry
    }
}
