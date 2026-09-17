import CorbieCore
import Foundation

struct PartnerDepartureWatcher: Sendable {
    @MainActor
    func observe(_ environment: AppEnvironment) async {
        let merges = NotificationCenter.default.notifications(named: RemoteChangesMerged.notificationName)
        for await _ in merges {
            await environment.reconcilePartnerMembership(
                serverCheckInterval: AppEnvironment.partnerCheckIntervalOnRemoteChange
            )
        }
    }
}
