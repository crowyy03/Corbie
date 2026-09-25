import Foundation

public struct StoreSubscription: Sendable, Equatable {
    public let transactionId: UInt64
    public let productId: String
    public let appAccountToken: UUID?
    public let environment: StoreEnvironment
    public let purchasedAt: Date
    public let expiresAt: Date?
    public let renewal: StoreRenewalState
    public let gracePeriodExpiresAt: Date?
    public let isInIntroOffer: Bool
    public let signedTransaction: String

    public init(
        transactionId: UInt64,
        productId: String,
        appAccountToken: UUID?,
        environment: StoreEnvironment,
        purchasedAt: Date,
        expiresAt: Date?,
        renewal: StoreRenewalState = .subscribed,
        gracePeriodExpiresAt: Date? = nil,
        isInIntroOffer: Bool = false,
        signedTransaction: String
    ) {
        self.transactionId = transactionId
        self.productId = productId
        self.appAccountToken = appAccountToken
        self.environment = environment
        self.purchasedAt = purchasedAt
        self.expiresAt = expiresAt
        self.renewal = renewal
        self.gracePeriodExpiresAt = gracePeriodExpiresAt
        self.isInIntroOffer = isInIntroOffer
        self.signedTransaction = signedTransaction
    }

    public var entitlement: LocalEntitlement {
        LocalEntitlement(
            productId: productId,
            renewal: renewal,
            expiresAt: expiresAt,
            gracePeriodExpiresAt: gracePeriodExpiresAt,
            isInIntroOffer: isInIntroOffer
        )
    }

    public func isActive(at moment: Date) -> Bool {
        EntitlementResolver.storeKitState(entitlement, now: moment) != nil
    }
}

public struct LocalSubscriptions: Sendable, Equatable {
    public let subscriptions: [StoreSubscription]

    public init(_ subscriptions: [StoreSubscription]) {
        self.subscriptions = subscriptions
    }

    public var production: LocalSubscriptions {
        LocalSubscriptions(subscriptions.filter { $0.environment == .production })
    }

    public func entitlement(for spaceId: UUID) -> LocalEntitlement? {
        let ownSpace = subscriptions.filter { $0.appAccountToken == spaceId }
        guard let latest = ownSpace.max(by: { $0.purchasedAt < $1.purchasedAt }) else { return nil }
        guard latest.renewal != .revoked else { return latest.entitlement }
        return ownSpace
            .filter { $0.renewal != .revoked }
            .map(\.entitlement)
            .reduce(nil) { best, candidate in LocalEntitlement.isNewer(candidate, than: best) ? candidate : best }
    }

    public func active(at moment: Date) -> [StoreSubscription] {
        subscriptions
            .filter { $0.isActive(at: moment) }
            .sorted { ($0.expiresAt ?? .distantFuture) > ($1.expiresAt ?? .distantFuture) }
    }

    public func activeOutside(_ spaceId: UUID, at moment: Date) -> StoreSubscription? {
        if let own = entitlement(for: spaceId), EntitlementResolver.storeKitState(own, now: moment) != nil { return nil }
        return active(at: moment).first { $0.appAccountToken != spaceId }
    }

    public func toReconcile(for spaceId: UUID, at moment: Date) -> StoreSubscription? {
        let ownSpace = subscriptions.filter { $0.appAccountToken == spaceId }.max { $0.purchasedAt < $1.purchasedAt }
        return activeOutside(spaceId, at: moment) ?? ownSpace
    }
}
