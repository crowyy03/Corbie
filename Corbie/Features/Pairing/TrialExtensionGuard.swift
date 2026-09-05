import CorbieCore
import Foundation

struct TrialExtensionGuard: Sendable {
    static let storagePrefix = "corbie.trial.partnerextension."

    private let suiteName: String

    init(suiteName: String = CorbieIdentifiers.appGroup) {
        self.suiteName = suiteName
    }

    func shouldExtend(spaceId: UUID, memberCount: Int) -> Bool {
        guard memberCount >= 2 else { return false }
        return defaults.bool(forKey: TrialExtensionGuard.key(spaceId)) == false
    }

    func markExtended(spaceId: UUID) {
        defaults.set(true, forKey: TrialExtensionGuard.key(spaceId))
    }

    static func key(_ spaceId: UUID) -> String {
        storagePrefix + spaceId.uuidString.lowercased()
    }

    private var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}
