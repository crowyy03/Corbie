import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class WishesViewModel {
    private(set) var active: [WishDTO] = []
    private(set) var fulfilled: [WishDTO] = []
    private(set) var rates: [String: FXRates] = [:]
    var filter: WishesFilter = .me
    var isFulfilledExpanded = false

    @ObservationIgnored private var environment: AppEnvironment?
    @ObservationIgnored private var attemptedParse: Set<UUID> = []
    @ObservationIgnored private var ratesTask: Task<Void, Never>?
    @ObservationIgnored private var didPickInitialFilter = false
    @ObservationIgnored private var storeChanges: StoreChangeSubscription?

    func configure(_ environment: AppEnvironment) {
        self.environment = environment
        if storeChanges == nil {
            storeChanges = environment.repositories.changes.subscribe { [weak self] in
                await self?.load()
            }
        }
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

    func wish(id: UUID) -> WishDTO? {
        active.first { $0.id == id } ?? fulfilled.first { $0.id == id }
    }

    func approximate(for wish: WishDTO) -> Money? {
        guard let environment, let money = WishPricing.money(for: wish) else { return nil }
        return WishPricing.approximate(
            money,
            in: environment.space?.displayCurrency ?? SupportedCurrencies.defaultCode,
            rates: rates[money.currency]
        )
    }

    func load() async {
        guard let environment, let space = environment.space else { return }
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
            guard let raw = wish.url, let url = LinkParser.normalize(raw) else { continue }
            let parsed: ParsedLink
            do {
                parsed = try await environment.linkParser.parse(url: url)
            } catch {
                WishLinkLog.failed(url, error: error, reader: .backgroundRetry)
                continue
            }
            guard parsed.isEmpty == false else {
                WishLinkLog.readEmpty(url, parsed: parsed, reader: .backgroundRetry)
                continue
            }
            let filled = try? await environment.repositories.wishes.fillEmptyFields(
                wishId: wish.id,
                parsedFrom: raw,
                with: parsed
            )
            if let filled, filled != wish {
                didChange = true
            }
        }
        if didChange {
            await load()
        }
    }

    func markGifted(_ wish: WishDTO) async {
        guard let environment, await WishActions(environment: environment).fulfil(wish.id) else { return }
        await load()
    }

    func delete(_ wish: WishDTO) async {
        guard let environment, await WishActions(environment: environment).delete(wish.id) else { return }
        await load()
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
