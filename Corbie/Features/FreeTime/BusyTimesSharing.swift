import CorbieCore
import Foundation

@MainActor
enum BusyTimesSharing {
    static func set(_ isOn: Bool, in environment: AppEnvironment) async {
        guard let member = environment.currentMember, member.sharesBusyTimes != isOn else { return }
        do {
            let updated = try await environment.repositories.members.setSharesBusyTimes(
                memberId: member.id,
                shares: isOn
            )
            environment.apply(member: updated)
        } catch {
            environment.report(error)
            return
        }
        if isOn {
            environment.analytics.record(.freetimeSharingEnabled)
            await environment.publishBusyTimes(force: true)
        } else {
            environment.analytics.record(.freetimeSharingDisabled)
            await environment.stopSharingBusyTimes()
        }
    }
}

enum BusyTimesPrivacyNotice {
    static let defaultsKey = "corbie.freetime.privacynotice.seen"

    static var hasBeenSeen: Bool {
        UserDefaults.corbieShared.bool(forKey: defaultsKey)
    }

    static func markSeen() {
        UserDefaults.corbieShared.set(true, forKey: defaultsKey)
    }
}
