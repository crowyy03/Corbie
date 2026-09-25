import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class PaywallViewModel {
    enum Stage: Equatable {
        case loading
        case ready
        case unavailable
    }

    private(set) var stage: Stage = .loading
    private(set) var offers: [SubscriptionOffer] = []
    private(set) var selection: CorbieProduct?
    private(set) var isWorking = false
    private(set) var message: String?
    var openedLink: LegalPage?

    @ObservationIgnored private var environment: AppEnvironment?

    var selectedOffer: SubscriptionOffer? {
        offers.first { $0.product == selection }
    }

    var canContinue: Bool {
        stage == .ready && selectedOffer != nil && isWorking == false
    }

    var isRestoring: Bool {
        environment?.premiumGate.isRestoring ?? false
    }

    func load(_ environment: AppEnvironment) async {
        self.environment = environment
        guard offers.isEmpty else { return }
        stage = .loading
        message = nil
        do {
            let loaded = try await environment.store.offers()
            offers = loaded
            selection = loaded.first?.product
            stage = loaded.isEmpty ? .unavailable : .ready
        } catch {
            stage = .unavailable
            environment.report(error)
        }
    }

    func reload(_ environment: AppEnvironment) async {
        offers = []
        await load(environment)
    }

    func select(_ product: CorbieProduct) {
        guard isWorking == false, selection != product else { return }
        selection = product
        guard let productId = selectedOffer?.productId else { return }
        environment?.analytics.record(.planSelected(productId: productId))
    }

    func purchase() async -> Bool {
        guard let environment, let offer = selectedOffer, isWorking == false else { return false }
        guard let space = environment.space else {
            message = PaywallCopy.text("paywall.state.nospace")
            environment.analytics.record(.purchaseFailed(reason: .noSpace))
            return false
        }
        #if DEBUG
        if environment.isScreenshotMode {
            environment.report(ScreenshotModeRefusal.purchase)
            return false
        }
        #endif
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            let outcome = try await environment.store.purchase(offer.product, appAccountToken: space.id)
            switch outcome {
            case let .success(signedTransaction):
                await environment.entitlements.syncPurchase(signedTransaction: signedTransaction, spaceId: space.id)
                await environment.refreshEntitlement()
                environment.toasts.show(message: PaywallCopy.text("paywall.state.purchased"))
                return true
            case .pending:
                message = PaywallCopy.text("paywall.state.pending")
                return false
            case .cancelled:
                return false
            }
        } catch {
            message = error.localizedDescription
            environment.report(error)
            return false
        }
    }

    func restore() async -> Bool {
        guard let environment, isWorking == false else { return false }
        isWorking = true
        message = nil
        defer { isWorking = false }
        let store = environment.store
        do {
            let outcome = try await environment.premiumGate.restore(spaceId: environment.space?.id) {
                try await store.restore()
            }
            switch outcome {
            case .restored:
                environment.toasts.show(message: PaywallCopy.restoreText(.restored))
                return environment.premiumGate.isPremium
            case .nothingToRestore:
                message = PaywallCopy.restoreText(.nothingToRestore)
                return false
            case nil:
                return false
            }
        } catch {
            message = error.localizedDescription
            environment.report(error)
            return false
        }
    }

    func open(_ link: LegalPage) {
        openedLink = link
    }
}
