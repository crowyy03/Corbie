import CorbieCore
import Foundation

struct PartnerJoinWatcher: Sendable {
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
        guard let space = environment.space, environment.partner == nil else { return }
        guard let members = try? await environment.repositories.members.members(spaceId: space.id),
              members.count >= 2
        else { return }
        await environment.reloadSession()
    }
}
