import CorbieCore
import Foundation
import Observation

@MainActor
@Observable
final class SettingsNotificationsViewModel {
    private(set) var prefs = NotificationPrefs.allEnabled
    private(set) var authorization: NotificationAuthorization = .notDetermined
    private(set) var isWorking = false

    private var environment: AppEnvironment?

    var isDenied: Bool { authorization == .denied }

    var isMuted: Bool { authorization == .denied || authorization == .notDetermined }

    func load(_ environment: AppEnvironment) async {
        self.environment = environment
        prefs = environment.currentMember?.notificationPrefs ?? .allEnabled
        authorization = await environment.notifications.authorizationStatus()
    }

    func refreshAuthorization() async {
        guard let environment else { return }
        authorization = await environment.notifications.authorizationStatus()
    }

    func binding(for toggle: SettingsNotificationToggle) -> Bool {
        toggle.isOn(in: prefs)
    }

    func set(_ toggle: SettingsNotificationToggle, isOn: Bool) async {
        guard let environment, let member = environment.currentMember else { return }
        let previous = prefs
        prefs = toggle.set(isOn, in: prefs)
        isWorking = true
        defer { isWorking = false }
        do {
            let updated = try await environment.repositories.members.updatePrefs(
                memberId: member.id,
                prefs: prefs
            )
            environment.apply(member: updated)
            guard toggle.scheduledKinds.isEmpty == false else { return }
            if isOn {
                await NotificationBacklog.resync(environment)
            } else {
                await environment.notifications.cancelAll(kinds: toggle.scheduledKinds)
            }
        } catch {
            prefs = previous
            environment.report(error)
        }
    }
}
