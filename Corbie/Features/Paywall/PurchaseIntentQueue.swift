import CorbieCore
import Foundation
import os
import StoreKit

@MainActor
final class PurchaseIntentQueue {
    struct Request: Sendable {
        let productId: String
        let buy: @Sendable (UUID) async throws -> PurchaseOutcome
    }

    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "paywall")

    private(set) var waiting: Request?
    private var isBuying = false

    func receive(_ request: Request, in environment: AppEnvironment) async {
        PurchaseIntentQueue.log.notice("purchase intent for \(request.productId, privacy: .public) arrived")
        waiting = request
        await buyWaiting(in: environment)
    }

    func buyWaiting(in environment: AppEnvironment) async {
        guard let request = waiting, isBuying == false else { return }
        guard let space = environment.space else {
            PurchaseIntentQueue.log.notice("purchase intent for \(request.productId, privacy: .public) waits for a space")
            return
        }
        waiting = nil
        #if DEBUG
        if environment.isScreenshotMode {
            environment.report(ScreenshotModeRefusal.purchase)
            return
        }
        #endif
        isBuying = true
        defer { isBuying = false }
        do {
            switch try await request.buy(space.id) {
            case let .success(signedTransaction):
                await environment.entitlements.syncPurchase(signedTransaction: signedTransaction, spaceId: space.id)
                await environment.refreshEntitlement()
                environment.toasts.show(message: PaywallCopy.text("paywall.state.purchased"))
            case .pending:
                environment.toasts.show(message: PaywallCopy.text("paywall.state.pending"))
            case .cancelled:
                PurchaseIntentQueue.log.notice("purchase intent for \(request.productId, privacy: .public) was cancelled")
            }
        } catch {
            let reason = (error as? LocalizedError)?.failureReason ?? error.localizedDescription
            PurchaseIntentQueue.log.error("purchase intent for \(request.productId, privacy: .public) failed: \(reason, privacy: .public)")
            environment.report(error)
        }
    }
}

extension PurchaseIntentQueue.Request {
    init(intent: PurchaseIntent, store: StoreService) {
        self.init(productId: intent.product.id) { spaceId in
            try await store.purchase(intent, appAccountToken: spaceId)
        }
    }
}
