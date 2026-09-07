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
        environment?.analytics.record(.planSelected(product: product))
    }

    func purchase() async -> Bool {
        guard let environment, let offer = selectedOffer, isWorking == false else { return false }
        guard let space = environment.space else {
            message = PaywallCopy.text("paywall.state.nospace")
            environment.analytics.record(.purchaseFailed(reason: .noSpace))
            return false
        }
        isWorking = true
        message = nil
        defer { isWorking = false }
        do {
            let outcome = try await environment.store.purchase(offer.product, appAccountToken: space.id)
            switch outcome {
            case .success:
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
        do {
            try await environment.store.restore()
            await environment.refreshEntitlement()
            guard environment.premiumGate.isPremium else {
                message = PaywallCopy.text("paywall.state.restore.empty")
                return false
            }
            environment.toasts.show(message: PaywallCopy.text("paywall.state.restored"))
            return true
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
