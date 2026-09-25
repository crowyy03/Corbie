import CorbieCore
import SwiftUI

struct PaywallRuntime: ViewModifier {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task { await startListening() }
            .task(id: environment.space?.id) { await refresh() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await refresh() }
            }
    }

    private func startListening() async {
        let environment = environment
        await environment.store.attachAnalytics(environment.analytics)
        await environment.store.startListening { [weak environment] subscription in
            await environment?.syncAndRefresh(after: subscription)
        }
    }

    private func refresh() async {
        await environment.refreshEntitlement()
    }
}

extension AppEnvironment {
    func syncAndRefresh(after subscription: StoreSubscription?) async {
        if let subscription, let spaceId = space?.id, subscription.appAccountToken == spaceId {
            await entitlements.syncPurchase(signedTransaction: subscription.signedTransaction, spaceId: spaceId)
        }
        await refreshEntitlement()
    }
}

extension View {
    func paywallRuntime() -> some View {
        modifier(PaywallRuntime())
    }
}
