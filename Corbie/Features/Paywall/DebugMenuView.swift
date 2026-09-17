#if DEBUG
import CorbieCore
import SwiftUI

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
        await environment.refreshEntitlement()
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

    func clearEntitlementCache(_ environment: AppEnvironment) async {
        guard let space = environment.space, isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        await environment.entitlements.clearCache(spaceId: space.id)
        await environment.reloadSession()
        lastAction = "entitlement cache cleared"
    }
}

struct DebugMenuView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model = DebugMenuViewModel()

    var body: some View {
        List {
            Section {
                ForEach(DebugMenuEntitlementRow.all) { entry in
                    row(entry.title) {
                        await model.force(entry.override, environment, label: entry.title)
                    }
                }
                row("Follow the real subscription") {
                    await model.force(nil as DebugEntitlementOverride?, environment, label: "override cleared")
                }
                row("Clear the entitlement cache") { await model.clearEntitlementCache(environment) }
            } header: {
                Text(verbatim: "Subscription")
            } footer: {
                Text(verbatim: state)
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

    private var monetizationState: String {
        let store = MonetizationFlagStore()
        let server = store.fetchedValue.map { $0 ? "on" : "off" } ?? "never fetched"
        let forced = DebugMonetizationOverride.stored()?.rawValue ?? "none"
        return "effective: \(store.isEnabled ? "on" : "off")\nserver: \(server)\nforced: \(forced)"
    }

    private var state: String {
        var lines = ["state: \(environment.premiumGate.state)"]
        if let endsAt = environment.premiumGate.trialEndsAt {
            lines.append("trial ends: \(endsAt.formatted(date: .abbreviated, time: .shortened))")
        }
        if let override = DebugEntitlementOverride.stored() {
            lines.append("forced: \(override.rawValue)")
        }
        if let lastAction = model.lastAction {
            lines.append(lastAction)
        }
        return lines.joined(separator: "\n")
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
        DebugMenuEntitlementRow(override: .readOnly, title: "Expire the trial"),
        DebugMenuEntitlementRow(override: .introOfferUsed, title: "Use up the intro offer"),
        DebugMenuEntitlementRow(override: .gracePeriod, title: "Force the grace period")
    ]
}

#Preview {
    NavigationStack {
        DebugMenuView()
    }
    .environment(AppEnvironment.previewSignedIn())
}
#endif
