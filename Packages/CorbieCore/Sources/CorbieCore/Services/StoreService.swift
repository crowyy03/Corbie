import Foundation
import StoreKit

public actor StoreService: LocalEntitlementProviding, AppTransactionProviding {
    public static let shared = StoreService()

    public nonisolated let productIdentifiers: StoreProductIdentifiers

    private var analytics: (any AnalyticsRecording)?
    private var products: [CorbieProduct: Product] = [:]
    private var updates: Task<Void, Never>?
    private var restoring: Task<Void, any Error>?
    private let appTransaction = StoreKitAppTransaction()

    public init(
        productIdentifiers: StoreProductIdentifiers = StoreProductIdentifiers(bundle: .main),
        analytics: (any AnalyticsRecording)? = nil
    ) {
        self.productIdentifiers = productIdentifiers
        self.analytics = analytics
    }

    deinit {
        updates?.cancel()
    }

    public func attachAnalytics(_ analytics: any AnalyticsRecording) {
        self.analytics = analytics
    }

    public func appTransactionProof() async -> AppTransactionProof? {
        await appTransaction.appTransactionProof()
    }

    public func loadProducts() async throws -> [CorbieProduct: Product] {
        do {
            let loaded = try await Product.products(for: productIdentifiers.all)
            var mapped: [CorbieProduct: Product] = [:]
            for product in loaded {
                guard let known = productIdentifiers.product(for: product.id) else { continue }
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
                    productId: storeProduct.id,
                    displayPrice: storeProduct.displayPrice,
                    price: storeProduct.price,
                    priceFormatStyle: storeProduct.priceFormatStyle,
                    eligibleFreeTrialDays: await eligibleFreeTrialDays(for: storeProduct)
                )
            )
        }
        return SubscriptionOfferMath.sorted(SubscriptionOfferMath.applySavings(to: offers))
    }

    public func purchase(_ product: CorbieProduct, appAccountToken: UUID) async throws -> PurchaseOutcome {
        let loaded = try await loadedProducts()
        guard let storeProduct = loaded[product] else {
            analytics?.record(.purchaseFailed(reason: .unavailable))
            throw CorbieError.notFound("product \(product.rawValue) is not available")
        }
        analytics?.record(.purchaseStarted(productId: storeProduct.id))
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
            let isTrial = StoreService.isInIntroOffer(transaction)
            if isTrial {
                analytics?.record(.trialStarted(productId: storeProduct.id))
            }
            analytics?.record(.purchaseCompleted(productId: storeProduct.id, isTrial: isTrial))
            return .success(signedTransaction: verification.jwsRepresentation)
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    public func restore() async throws {
        let running = restoring ?? startRestoring()
        defer {
            if restoring == running { restoring = nil }
        }
        do {
            try await running.value
        } catch {
            throw CorbieError.network("restore failed: \(error)")
        }
    }

    private func startRestoring() -> Task<Void, any Error> {
        analytics?.record(.restoreTapped)
        let running = Task { try await AppStore.sync() }
        restoring = running
        return running
    }

    public func subscriptions() async -> [StoreSubscription] {
        if let group = await subscriptionGroupID(),
           let statuses = try? await Product.SubscriptionInfo.status(for: group) {
            let fromStatuses = statuses.compactMap { status in
                subscription(from: status.transaction, status: status)
            }
            if fromStatuses.isEmpty == false { return fromStatuses }
        }
        var current: [StoreSubscription] = []
        for await result in Transaction.currentEntitlements {
            guard let record = subscription(from: result, status: nil) else { continue }
            current.append(record)
        }
        return current
    }

    public func startListening(onTransaction: @escaping @Sendable (StoreSubscription?) async -> Void) {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await update in Transaction.updates {
                guard let transaction = try? StoreService.verified(update) else { continue }
                await transaction.finish()
                await onTransaction(await self?.subscription(from: update, status: nil))
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

    private func subscription(
        from result: VerificationResult<Transaction>,
        status: Product.SubscriptionInfo.Status?
    ) -> StoreSubscription? {
        guard let transaction = try? StoreService.verified(result),
              productIdentifiers.product(for: transaction.productID) != nil,
              let environment = StoreEnvironment(transaction.environment)
        else { return nil }
        let renewal = status.flatMap { try? StoreService.verified($0.renewalInfo) }
        return StoreSubscription(
            transactionId: transaction.id,
            productId: transaction.productID,
            appAccountToken: transaction.appAccountToken,
            environment: environment,
            purchasedAt: transaction.purchaseDate,
            expiresAt: transaction.expirationDate,
            renewal: StoreService.renewalState(status?.state, isRevoked: transaction.revocationDate != nil),
            gracePeriodExpiresAt: renewal?.gracePeriodExpirationDate,
            isInIntroOffer: StoreService.isInIntroOffer(transaction),
            signedTransaction: result.jwsRepresentation
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
        transaction.offer?.type == .introductory
    }
}
