import CorbieCore
import SwiftUI

struct TrialStartReporter: Sendable {
    static let storagePrefix = "corbie.trial.started."

    private let suiteName: String

    init(suiteName: String = CorbieIdentifiers.appGroup) {
        self.suiteName = suiteName
    }

    static func key(_ spaceId: UUID) -> String {
        storagePrefix + spaceId.uuidString.lowercased()
    }

    static func shouldRecord(state: EntitlementState, wasRecorded: Bool) -> Bool {
        guard wasRecorded == false else { return false }
        return state.trialDaysLeft != nil
    }

    func recordIfNeeded(spaceId: UUID, state: EntitlementState, analytics: any AnalyticsRecording) {
        let key = TrialStartReporter.key(spaceId)
        guard TrialStartReporter.shouldRecord(state: state, wasRecorded: defaults.bool(forKey: key)) else { return }
        defaults.set(true, forKey: key)
        analytics.record(.trialStarted)
    }

    private var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}

struct PaywallRuntime: ViewModifier {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase

    private let reporter = TrialStartReporter()

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
        await environment.store.startListening { _ in
            await environment.refreshEntitlement()
        }
    }

    private func refresh() async {
        guard let space = environment.space else { return }
        await environment.refreshEntitlement()
        reporter.recordIfNeeded(
            spaceId: space.id,
            state: environment.premiumGate.state,
            analytics: environment.analytics
        )
    }
}

extension View {
    func paywallRuntime() -> some View {
        modifier(PaywallRuntime())
    }
}
