import CorbieCore
import Foundation

struct PartnerChangeWatcher: Sendable {
    @MainActor
    func observe(_ environment: AppEnvironment) async {
        await check(environment)
        let changes = NotificationCenter.default.notifications(named: WidgetReloadRequest.notificationName)
        for await _ in changes {
            await check(environment)
        }
    }

    @MainActor
    func check(_ environment: AppEnvironment) async {
        await environment.reloadSessionIfPartnerChanged()
    }
}
