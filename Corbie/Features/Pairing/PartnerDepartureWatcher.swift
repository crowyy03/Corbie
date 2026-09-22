import CorbieCore
import Foundation

struct PartnerDepartureWatcher: Sendable {
    @MainActor
    func observe(_ environment: AppEnvironment) async {
        for await change in environment.repositories.changes.stream() where change.origin == .elsewhere {
            await environment.reconcilePartnerMembership(
                serverCheckInterval: AppEnvironment.partnerCheckIntervalOnRemoteChange
            )
        }
    }
}
