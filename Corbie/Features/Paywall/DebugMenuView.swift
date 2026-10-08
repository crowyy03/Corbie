#if DEBUG
import CloudKit
import CorbieCore
import StoreKit
import SwiftUI
import UIKit

@MainActor
@Observable
final class DebugMenuViewModel {
    private(set) var lastAction: String?
    private(set) var isWorking = false

    func force(_ override: DebugEntitlementOverride?, _ environment: AppEnvironment, label: String) async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        DebugEntitlementOverride.store(override)
        if override != nil {
            DebugMonetizationOverride.store(.on)
        }
        await environment.refreshEntitlement()
        lastAction = override == nil ? label : "\(label), monetization forced on"
    }

    func openPaywall(_ environment: AppEnvironment) async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        DebugMonetizationOverride.store(.on)
        await environment.refreshEntitlement()
        environment.premiumGate.pendingPaywall = PaywallRequest(reason: .settings)
        lastAction = "paywall opened, monetization forced on"
    }

    func showPaywallAfterFreeWindowAgain(_ environment: AppEnvironment, appState: AppState) async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        DebugMonetizationOverride.store(.on)
        FreeWindowPaywallFlag(defaults: environment.defaults).forget()
        await environment.refreshEntitlement()
        guard environment.premiumGate.isPremium == false else {
            lastAction = "paywall armed again; it shows once the state is read-only, so end the free window first"
            return
        }
        appState.isUsHubPresented = false
        appState.freeWindowPaywallChecks += 1
        lastAction = "paywall after the free window shown, monetization forced on"
    }

    func endFreeWindow(_ override: DebugFreeWindowOverride?, _ environment: AppEnvironment, label: String) async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        DebugFreeWindowOverride.store(override)
        await environment.refreshEntitlement()
        WidgetReloadRequest.post()
        lastAction = label
    }

    func force(_ override: DebugMonetizationOverride?, _ environment: AppEnvironment, label: String) async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        DebugMonetizationOverride.store(override)
        await environment.refreshEntitlement()
        lastAction = label
    }

    func requestRefund(spaceId: UUID?) async {
        guard isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        lastAction = await DebugRefundRequest.start(spaceId: spaceId)
    }

    func clearEntitlementCache(_ environment: AppEnvironment) async {
        guard let space = environment.space, isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        await environment.entitlements.clearCache(spaceId: space.id)
        await environment.reloadSession()
        lastAction = "entitlement cache cleared"
    }

    func deleteServerShare(_ environment: AppEnvironment) async {
        guard let space = environment.space, isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            guard let share = try environment.sharing.existingShare(for: space.id) else {
                lastAction = "share: this space is not shared yet"
                return
            }
            let database = CKContainer(identifier: CorbieIdentifiers.cloudKitContainer).privateCloudDatabase
            _ = try await database.deleteRecord(withID: share.recordID)
            lastAction = "share \(share.recordID.recordName) deleted on the server, this phone still remembers it"
        } catch {
            lastAction = "share delete failed: \(CloudKitFailure.describe(error))"
        }
    }
}

struct DebugMenuView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppState.self) private var appState
    @State private var model = DebugMenuViewModel()

    var body: some View {
        List {
            Section {
                Text(verbatim: state)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                Text(verbatim: "Status")
            }
            ScreenshotModeSection()
            Section {
                ForEach(DebugMenuEntitlementRow.all) { entry in
                    row(entry.title) {
                        await model.force(entry.override, environment, label: entry.title)
                    }
                }
                row("Follow the real subscription") {
                    await model.force(nil as DebugEntitlementOverride?, environment, label: "override cleared")
                }
                row("Open the paywall") { await model.openPaywall(environment) }
                row("Show the paywall after the free window again") {
                    await model.showPaywallAfterFreeWindowAgain(environment, appState: appState)
                }
                row("Clear the entitlement cache") { await model.clearEntitlementCache(environment) }
                row("Request a refund") { await model.requestRefund(spaceId: environment.space?.id) }
            } header: {
                Text(verbatim: "Subscription")
            } footer: {
                Text(verbatim: "Forcing a state, opening the paywall or the paywall after the free window also forces monetization on: a subscription state means nothing while it is off. A forced state wins over the free window.")
            }
            Section {
                row("End free window now") {
                    await model.endFreeWindow(.ended, environment, label: "free window ended on this phone")
                }
                row("Follow the real free window") {
                    await model.endFreeWindow(nil, environment, label: "free window follows the space")
                }
            } header: {
                Text(verbatim: "Free window")
            } footer: {
                Text(verbatim: "Ending it touches only this phone: the space and the partner keep the real window.")
            }
            Section {
                row("Follow the server flag") {
                    await model.force(nil as DebugMonetizationOverride?, environment, label: "monetization follows the server")
                }
                row("Force monetization on") {
                    await model.force(DebugMonetizationOverride.on, environment, label: "monetization forced on")
                }
                row("Force monetization off") {
                    await model.force(DebugMonetizationOverride.off, environment, label: "monetization forced off")
                }
            } header: {
                Text(verbatim: "Monetization")
            } footer: {
                Text(verbatim: monetizationState)
            }
            Section {
                row("Delete this space's share on the server") { await model.deleteServerShare(environment) }
            } header: {
                Text(verbatim: "Pairing")
            } footer: {
                Text(verbatim: "The next invite code has to find the share gone and make a new one.")
            }
            Section {
                Text(verbatim: serverState)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                Text(verbatim: "Server")
            }
            DebugNotificationsSections()
        }
        .navigationTitle(Text(verbatim: "Developer"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ title: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Text(verbatim: title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .disabled(model.isWorking)
    }

    private var serverState: String {
        """
        \(environment.apiClient.configuration.summary)
        cloudkit \(environment.sharing.environment?.rawValue ?? "undeclared")
        version \(AppVersion.current())
        \(environment.storage?.summary ?? "storage not probed yet")
        """
    }

    private var monetizationState: String {
        let store = MonetizationConfigStore()
        let server = store.fetchedValue.map { $0 ? "on" : "off" } ?? "never fetched"
        let forced = DebugMonetizationOverride.stored()?.rawValue ?? "none"
        let days = store.fetchedFreeDays.map { "\($0) from the server" } ?? "\(FreeWindow.defaultDays), never fetched"
        return "effective: \(store.isEnabled ? "on" : "off")\nserver monetization_v2_enabled: \(server)\nforced: \(forced)\nfree days: \(days)"
    }

    private var state: String {
        let monetization = MonetizationConfigStore()
        let gate = environment.premiumGate
        var lines = [
            "space: \(environment.space?.id.uuidString.lowercased() ?? "none")",
            "monetization: \(monetization.isEnabled ? "on" : "off"), \(DebugMenuStatus.monetizationSource(monetization))",
            "state: \(gate.state)"
        ]
        if let cause = gate.readOnlyCause {
            lines.append("read-only because: \(cause.rawValue)")
        }
        if let endsAt = gate.trialEndsAt {
            lines.append("trial ends: \(endsAt.formatted(date: .abbreviated, time: .shortened))")
        }
        lines.append(DebugMenuStatus.freeWindowLine(space: environment.space, store: monetization, now: Date()))
        if let override = DebugEntitlementOverride.stored() {
            lines.append(DebugMenuStatus.overrideLine(override, monetizationOn: monetization.isEnabled))
        } else {
            lines.append("forced state: none, this is the real one")
        }
        if let lastAction = model.lastAction {
            lines.append(lastAction)
        }
        return lines.joined(separator: "\n")
    }
}

enum DebugRefundRequest {
    @MainActor
    static func start(spaceId: UUID?) async -> String {
        guard let transaction = await latestSubscriptionTransaction() else {
            return "refund: no verified subscription transaction on this Apple ID"
        }
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            return "refund: no active window"
        }
        let owner = spaceId != nil && transaction.appAccountToken == spaceId ? "this space" : "another space"
        let target = "\(transaction.productID) \(transaction.id), bought for \(owner)"
        do {
            let status = try await StoreKit.Transaction.beginRefundRequest(for: transaction.id, in: scene)
            return "refund \(status == .success ? "requested" : "cancelled"): \(target)"
        } catch {
            return "refund failed: \(error.localizedDescription), \(target)"
        }
    }

    private static func latestSubscriptionTransaction() async -> StoreKit.Transaction? {
        var latest: StoreKit.Transaction?
        for productId in StoreProductIdentifiers(bundle: .main).all {
            guard case let .verified(transaction)? = await StoreKit.Transaction.latest(for: productId) else { continue }
            if let current = latest, current.purchaseDate >= transaction.purchaseDate { continue }
            latest = transaction
        }
        return latest
    }
}

enum DebugMenuStatus {
    static func monetizationSource(_ store: MonetizationConfigStore) -> String {
        if let forced = DebugMonetizationOverride.stored() {
            return "forced \(forced.rawValue) here"
        }
        guard let fetched = store.fetchedValue else { return "server never asked, counts as on" }
        return "server says \(fetched ? "on" : "off")"
    }

    static func freeWindowLine(space: SpaceDTO?, store: MonetizationConfigStore, now: Date, calendar: Calendar = .current) -> String {
        guard let space else { return "free window: no space" }
        let days = store.fetchedFreeDays ?? FreeWindow.defaultDays
        guard let window = FreeWindow(spaceCreatedAt: space.createdAt, days: days, calendar: calendar) else {
            return "free window: none (\(days) days, space created \(space.createdAt.map(describe) ?? "never"))"
        }
        let ended = DebugFreeWindowOverride.stored() == .ended ? ", ended on this phone by the developer" : ""
        let verb = window.isOpen(at: now) ? "ends" : "ended"
        return "free window \(verb) \(describe(window.endsAt))\(ended)"
    }

    private static func describe(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    static func overrideLine(_ override: DebugEntitlementOverride, monetizationOn: Bool) -> String {
        guard monetizationOn else {
            return "forced: \(override.rawValue), ignored while monetization is off"
        }
        return "forced: \(override.rawValue), in effect"
    }
}

struct DebugMenuEntitlementRow: Identifiable {
    let override: DebugEntitlementOverride
    let title: String

    var id: String { override.rawValue }

    static let all: [DebugMenuEntitlementRow] = [
        DebugMenuEntitlementRow(override: .premium, title: "Force premium"),
        DebugMenuEntitlementRow(
            override: .trialEnding,
            title: "End the trial in \(PremiumGate.trialNoticeDays) days"
        ),
        DebugMenuEntitlementRow(override: .trialEnded, title: "Expire the trial"),
        DebugMenuEntitlementRow(override: .subscriptionEnded, title: "End the subscription"),
        DebugMenuEntitlementRow(override: .introOfferUsed, title: "Use up the intro offer"),
        DebugMenuEntitlementRow(override: .gracePeriod, title: "Force the grace period")
    ]
}

#Preview {
    NavigationStack {
        DebugMenuView()
    }
    .environment(AppEnvironment.previewSignedIn())
    .environment(AppState())
}
#endif
