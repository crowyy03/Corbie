#if DEBUG
import CorbieCore
import SwiftUI

@MainActor
@Observable
final class DebugMenuViewModel {
    private(set) var lastAction: String?
    private(set) var isWorking = false

    func expireTrial(_ environment: AppEnvironment) async {
        await change(environment, label: "trial expired") { space, now in
            var updated = space
            updated.trialEndsAt = now.addingTimeInterval(-60)
            return updated
        }
    }

    func endTrialSoon(_ environment: AppEnvironment, inDays days: Int) async {
        await change(environment, label: "trial ends in \(days) days") { space, now in
            var updated = space
            updated.trialEndsAt = now.addingTimeInterval(Double(days) * 86_400)
            updated.subscriptionStatus = .trial
            return updated
        }
    }

    func extendTrial(_ environment: AppEnvironment, days: Int) async {
        await change(environment, label: "trial extended by \(days) days") { space, now in
            var updated = space
            let base = max(space.trialEndsAt ?? now, now)
            updated.trialEndsAt = base.addingTimeInterval(Double(days) * 86_400)
            return updated
        }
    }

    func resetTrial(_ environment: AppEnvironment) async {
        await change(environment, label: "trial reset") { space, now in
            var updated = space
            updated.trialEndsAt = now.addingTimeInterval(Double(SpaceDTO.trialDays) * 86_400)
            updated.subscriptionStatus = .trial
            updated.subscriptionExpiresAt = nil
            return updated
        }
    }

    func clearEntitlementCache(_ environment: AppEnvironment) async {
        guard let space = environment.space, isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        await environment.entitlements.clearCache(spaceId: space.id)
        await environment.reloadSession()
        lastAction = "entitlement cache cleared"
    }

    private func change(
        _ environment: AppEnvironment,
        label: String,
        transform: @Sendable (SpaceDTO, Date) -> SpaceDTO
    ) async {
        guard let space = environment.space, isWorking == false else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            _ = try await environment.repositories.spaces.update(transform(space, Date()))
            await environment.reloadSession()
            lastAction = label
        } catch {
            environment.report(error)
        }
    }
}

struct DebugMenuView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model = DebugMenuViewModel()

    var body: some View {
        List {
            Section {
                row("Expire the trial") { await model.expireTrial(environment) }
                row("End the trial in \(PremiumGate.trialNoticeDays) days") {
                    await model.endTrialSoon(environment, inDays: PremiumGate.trialNoticeDays)
                }
                row("Extend the trial by 7 days") { await model.extendTrial(environment, days: 7) }
                row("Reset the trial") { await model.resetTrial(environment) }
                row("Clear the entitlement cache") { await model.clearEntitlementCache(environment) }
            } header: {
                Text(verbatim: "Subscription")
            } footer: {
                Text(verbatim: state)
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

    private var state: String {
        var lines = ["state: \(environment.premiumGate.state)"]
        if let trialEndsAt = environment.space?.trialEndsAt {
            lines.append("trial ends: \(trialEndsAt.formatted(date: .abbreviated, time: .shortened))")
        }
        if let lastAction = model.lastAction {
            lines.append(lastAction)
        }
        return lines.joined(separator: "\n")
    }
}

#Preview {
    NavigationStack {
        DebugMenuView()
    }
    .environment(AppEnvironment.previewSignedIn())
}
#endif
