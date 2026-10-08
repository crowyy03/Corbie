import CorbieCore
import Foundation

struct FreeWindowPaywallFlag {
    static let storageKey = "corbie.paywall.shownAfterFreeWindow"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .corbieShared) {
        self.defaults = defaults
    }

    func hasBeenShown(spaceId: UUID) -> Bool {
        defaults.string(forKey: FreeWindowPaywallFlag.storageKey) == spaceId.uuidString
    }

    static func mayClaim(_ state: EntitlementState) -> Bool {
        state.isReadOnly
    }

    func claim(spaceId: UUID) -> Bool {
        guard hasBeenShown(spaceId: spaceId) == false else { return false }
        defaults.set(spaceId.uuidString, forKey: FreeWindowPaywallFlag.storageKey)
        return true
    }

    #if DEBUG
    func forget() {
        defaults.removeObject(forKey: FreeWindowPaywallFlag.storageKey)
    }
    #endif
}
