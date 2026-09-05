import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class WishesViewModel {
    private(set) var active: [WishDTO] = []
    private(set) var fulfilled: [WishDTO] = []
    private(set) var rates: [String: FXRates] = [:]
    private(set) var isLoading = false
    var filter: WishesFilter = .me
    var isFulfilledExpanded = false

    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var attemptedParse: Set<UUID> = []
    @ObservationIgnored private var ratesTask: Task<Void, Never>?
    @ObservationIgnored private var didPickInitialFilter = false

    func configure(_ environment: AppEnvironment) {
        self.environment = environment
        guard didPickInitialFilter == false, environment.isSignedIn else { return }
        didPickInitialFilter = true
        filter = WishesFilter.defaultSelection(isPaired: environment.isPaired)
    }

    var owners: WishesOwners {
        WishesOwners(me: environment?.currentMember?.id, partner: environment?.partner?.id)
    }

    var availableFilters: [WishesFilter] {
        WishesFilter.available(isPaired: environment?.isPaired ?? false)
    }

    var visibleActive: [WishDTO] {
        WishesGrouping.wishes(active, matching: filter, owners: owners)
    }

    var visibleFulfilled: [WishDTO] {
        WishesGrouping.wishes(fulfilled, matching: filter, owners: owners)
    }

    func count(for filter: WishesFilter) -> Int {
        WishesGrouping.count(active, matching: filter, owners: owners)
    }

    func label(for filter: WishesFilter) -> String {
        switch filter {
        case .partner: return environment?.partnerName ?? String(localized: "member.name.partner")
        case .me: return String(localized: "wishes.chip.me")
        case .all: return String(localized: "wishes.chip.all")
        }
    }

    func resetFilter() {
        filter = WishesFilter.defaultSelection(isPaired: environment?.isPaired ?? false)
    }

    func approximate(for wish: WishDTO) -> Money? {
        guard let environment, let money = WishPricing.money(for: wish) else { return nil }
        return WishPricing.approximate(
            money,
            in: environment.space?.displayCurrency ?? "USD",
            rates: rates[money.currency]
        )
    }

    func load() async {
        guard let environment, let space = environment.space else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let stored = try await environment.repositories.wishes.wishes(
                WishQuery(spaceId: space.id, owner: .any, fulfilled: nil)
            )
            active = stored.filter { $0.isFulfilled == false }
            fulfilled = stored.filter(\.isFulfilled)
            filter = filter.resolved(isPaired: environment.isPaired)
            refreshRates(for: stored, displayCurrency: space.displayCurrency)
        } catch {
            environment.report(error)
        }
    }

    func retryPendingParse(isOnline: Bool) async {
        guard let environment else { return }
        let pending = WishParseRetry.candidates(in: active, attempted: attemptedParse, isOnline: isOnline)
        guard pending.isEmpty == false else { return }
        var didChange = false
        for wish in pending {
            attemptedParse.insert(wish.id)
            guard let raw = wish.url,
                  let parsed = try? await environment.linkParser.parse(rawURL: raw)
            else { continue }
            let filled = WishParsedFill.merged(parsed, into: wish)
            if (try? await environment.repositories.wishes.update(filled)) != nil {
                didChange = true
            }
        }
        if didChange {
            await load()
        }
    }

    func markGifted(_ wish: WishDTO) async {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        do {
            _ = try await environment.repositories.wishes.fulfil(wishId: wish.id)
            environment.analytics.record(.wishFulfilled)
            await load()
        } catch {
            environment.report(error)
        }
    }

    func delete(_ wish: WishDTO) async {
        guard let environment, environment.premiumGate.require(.edit) else { return }
        do {
            try await environment.repositories.wishes.delete(id: wish.id)
            await load()
        } catch {
            environment.report(error)
        }
    }

    private func refreshRates(for wishes: [WishDTO], displayCurrency: String) {
        guard let environment else { return }
        let needed = WishPricing.currenciesNeedingRates(wishes, displayCurrency: displayCurrency)
        guard needed.isEmpty == false else { return }
        for code in needed where rates[code] == nil {
            rates[code] = environment.fx.cachedRates(base: code)
        }
        ratesTask?.cancel()
        let fx = environment.fx
        ratesTask = Task { [weak self] in
            for code in needed {
                guard Task.isCancelled == false else { return }
                guard let table = try? await fx.rates(base: code) else { continue }
                self?.rates[code] = table
            }
        }
    }
}
