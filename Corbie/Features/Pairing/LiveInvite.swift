import CorbieCore
import Foundation

struct LiveInvite: Codable, Equatable {
    let code: String
    let expiresAt: Date
    let spaceId: UUID
    let existingPartnerId: UUID?
}

struct LiveInviteStore {
    static let storageKey = "corbie.pairing.liveInvite"

    private let suiteName: String

    init(suiteName: String = CorbieIdentifiers.appGroup) {
        self.suiteName = suiteName
    }

    func live(for spaceId: UUID, at now: Date) -> LiveInvite? {
        guard let data = defaults.data(forKey: LiveInviteStore.storageKey),
              let invite = try? JSONDecoder().decode(LiveInvite.self, from: data),
              invite.spaceId == spaceId,
              invite.expiresAt > now
        else { return nil }
        return invite
    }

    func save(_ invite: LiveInvite) {
        guard let data = try? JSONEncoder().encode(invite) else { return }
        defaults.set(data, forKey: LiveInviteStore.storageKey)
    }

    func forget() {
        defaults.removeObject(forKey: LiveInviteStore.storageKey)
    }

    private var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
