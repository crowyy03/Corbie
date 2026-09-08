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
        let loaded = try await loadedProducts()
        var offers: [SubscriptionOffer] = []
        for (product, storeProduct) in loaded {
            offers.append(
                SubscriptionOffer(
                    product: product,
                    displayPrice: storeProduct.displayPrice,
                    price: storeProduct.price,
                    priceFormatStyle: storeProduct.priceFormatStyle,
                    eligibleFreeTrialDays: await eligibleFreeTrialDays(for: storeProduct)
                )
            )
        }
        return SubscriptionOfferMath.sorted(SubscriptionOfferMath.applySavings(to: offers))
    }

    public func eligibleFreeTrialDays(_ product: CorbieProduct) async throws -> Int? {
        let loaded = try await loadedProducts()
        guard let storeProduct = loaded[product] else {
            throw CorbieError.notFound("product \(product.identifier) is not available")
        }
        return await eligibleFreeTrialDays(for: storeProduct)
    }

    public func purchase(_ product: CorbieProduct, appAccountToken: UUID) async throws -> PurchaseOutcome {
        let loaded = try await loadedProducts()
        guard let storeProduct = loaded[product] else {
            analytics?.record(.purchaseFailed(reason: .unavailable))
            throw CorbieError.notFound("product \(product.identifier) is not available")
        }
        analytics?.record(.purchaseStarted(product: product))
        let result: Product.PurchaseResult
        do {
            result = try await storeProduct.purchase(options: [.appAccountToken(appAccountToken)])
        } catch {
            analytics?.record(.purchaseFailed(reason: .storeError))
            throw CorbieError.network("purchase failed: \(error)")
        }
        switch result {
        case let .success(verification):
            let transaction: Transaction
            do {
                transaction = try StoreService.verified(verification)
            } catch {
                analytics?.record(.purchaseFailed(reason: .unverified))
                throw error
            }
            await transaction.finish()
            let entitlement = StoreService.entitlement(from: transaction, status: nil)
            if entitlement.isInIntroOffer {
                analytics?.record(.trialStarted(product: product))
            }
            analytics?.record(.purchaseCompleted(product: product, isTrial: entitlement.isInIntroOffer))
            return .success(entitlement)
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    public func restore() async throws {
        analytics?.record(.restoreTapped)
        do {
            try await AppStore.sync()
        } catch {
            throw CorbieError.network("restore failed: \(error)")
        }
    }

    public func currentEntitlement() async -> LocalEntitlement? {
        if let group = await subscriptionGroupID(),
           let statuses = try? await Product.SubscriptionInfo.status(for: group) {
            var best: LocalEntitlement?
            for status in statuses {
                guard let candidate = StoreService.entitlement(from: status) else { continue }
                if StoreService.isNewer(candidate, than: best) { best = candidate }
            }
            if best != nil { return best }
        }
        var best: LocalEntitlement?
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? StoreService.verified(result),
                  CorbieProduct(identifier: transaction.productID) != nil
            else { continue }
            let candidate = StoreService.entitlement(from: transaction, status: nil)
            guard candidate.renewal != .revoked else { continue }
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

    private func loadedProducts() async throws -> [CorbieProduct: Product] {
        products.isEmpty ? try await loadProducts() : products
    }

    private func subscriptionGroupID() async -> String? {
        let loaded = (try? await loadedProducts()) ?? products
        return loaded.values.compactMap { $0.subscription?.subscriptionGroupID }.first
    }

    private func eligibleFreeTrialDays(for product: Product) async -> Int? {
        #if DEBUG
        if DebugEntitlementOverride.stored()?.hidesIntroOffer == true { return nil }
        #endif
        guard let subscription = product.subscription,
              let offer = subscription.introductoryOffer,
              offer.paymentMode == .freeTrial,
              await subscription.isEligibleForIntroOffer
        else { return nil }
        return SubscriptionOfferMath.freeTrialDays(
            unit: StoreService.unit(of: offer.period),
            value: offer.period.value,
            periodCount: offer.periodCount
        )
    }

    static func unit(of period: Product.SubscriptionPeriod) -> SubscriptionPeriodUnit {
        switch period.unit {
        case .day: return .day
        case .week: return .week
        case .month: return .month
        case .year: return .year
        @unknown default: return .day
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

    static func entitlement(from status: Product.SubscriptionInfo.Status) -> LocalEntitlement? {
        guard let transaction = try? StoreService.verified(status.transaction),
              CorbieProduct(identifier: transaction.productID) != nil
        else { return nil }
        return StoreService.entitlement(from: transaction, status: status)
    }

    static func entitlement(from transaction: Transaction, status: Product.SubscriptionInfo.Status?) -> LocalEntitlement {
        let renewal = status.flatMap { try? StoreService.verified($0.renewalInfo) }
        return LocalEntitlement(
            productId: transaction.productID,
            renewal: StoreService.renewalState(status?.state, isRevoked: transaction.revocationDate != nil),
            expiresAt: transaction.expirationDate,
            gracePeriodExpiresAt: renewal?.gracePeriodExpirationDate,
            isInIntroOffer: StoreService.isInIntroOffer(transaction)
        )
    }

    static func renewalState(_ state: Product.SubscriptionInfo.RenewalState?, isRevoked: Bool) -> StoreRenewalState {
        if isRevoked { return .revoked }
        guard let state else { return .subscribed }
        switch state {
        case .subscribed: return .subscribed
        case .inGracePeriod: return .inGracePeriod
        case .inBillingRetryPeriod: return .inBillingRetry
        case .revoked: return .revoked
        default: return .expired
        }
    }

    static func isInIntroOffer(_ transaction: Transaction) -> Bool {
        guard #available(iOS 17.2, macOS 14.2, *) else { return false }
        return transaction.offer?.type == .introductory
    }

    static func isNewer(_ candidate: LocalEntitlement, than current: LocalEntitlement?) -> Bool {
        guard let current else { return true }
        guard let candidateExpiry = candidate.expiresAt else { return true }
        guard let currentExpiry = current.expiresAt else { return false }
        return candidateExpiry > currentExpiry
    }
}
