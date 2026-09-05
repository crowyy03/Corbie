import CorbieCore
import Foundation

struct PartnerJoinWatcher: Sendable {
    private let trialGuard: TrialExtensionGuard

    init(trialGuard: TrialExtensionGuard = TrialExtensionGuard()) {
        self.trialGuard = trialGuard
    }

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
        guard let space = environment.space else { return }
        guard let members = try? await environment.repositories.members.members(spaceId: space.id),
              members.count >= 2
        else { return }
        if trialGuard.shouldExtend(spaceId: space.id, memberCount: members.count) {
            _ = try? await environment.entitlements.extendTrialForSecondMember(space: space)
            trialGuard.markExtended(spaceId: space.id)
            await environment.reloadSession()
            return
        }
        if environment.partner == nil {
            await environment.reloadSession()
        }
    }
}
