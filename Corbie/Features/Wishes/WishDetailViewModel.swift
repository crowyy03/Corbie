import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class WishDetailViewModel {
    private(set) var wish: WishDTO?
    private(set) var approximate: Money?
    private(set) var isGone = false
    var editor: WishEditorRequest?
    var isConfirmingDelete = false

    @ObservationIgnored let wishId: UUID
    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var storeChanges: StoreChangeSubscription?

    init(wishId: UUID, wish: WishDTO? = nil, approximate: Money? = nil) {
        self.wishId = wishId
        self.wish = wish
        self.approximate = approximate
    }

    func attach(_ environment: AppEnvironment) {
        self.environment = environment
        guard storeChanges == nil else { return }
        storeChanges = environment.repositories.changes.subscribe { [weak self] in
            await self?.load()
        }
    }

    func load() async {
        guard let environment else { return }
        do {
            guard let stored = try await environment.repositories.wishes.wish(id: wishId) else {
                isGone = true
                return
            }
            wish = stored
            approximate = approximate(for: stored, in: environment)
        } catch {
            environment.report(error)
        }
    }

    func startEditing() {
        guard let wish, let environment, environment.premiumGate.require(.edit) else { return }
        editor = WishEditorRequest(wish: wish, link: nil)
    }

    func startDeleting() {
        guard wish != nil, let environment, environment.premiumGate.require(.edit) else { return }
        isConfirmingDelete = true
    }

    func delete() async {
        guard let environment, await WishActions(environment: environment).delete(wishId) else { return }
        isGone = true
    }

    func fulfil() async {
        guard let environment, wish?.isFulfilled == false else { return }
        guard await WishActions(environment: environment).fulfil(wishId) else { return }
        await load()
    }

    private func approximate(for wish: WishDTO, in environment: AppEnvironment) -> Money? {
        guard let money = WishPricing.money(for: wish) else { return nil }
        return WishPricing.approximate(
            money,
            in: environment.space?.displayCurrency ?? SupportedCurrencies.defaultCode,
            rates: environment.fx.cachedRates(base: money.currency)
        )
    }
}
