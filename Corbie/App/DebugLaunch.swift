#if DEBUG
import CorbieCore
import Foundation

enum DebugLaunch {
    static let resetStoreArgument = "-corbie-reset-store"
    static let entitlementArgument = "-corbie-entitlement"

    static func applyEntitlementArgument(arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard let flag = arguments.firstIndex(of: entitlementArgument), flag + 1 < arguments.count,
              let override = DebugEntitlementOverride(rawValue: arguments[flag + 1])
        else { return }
        DebugEntitlementOverride.store(override)
    }

    static func resetStoreIfRequested(arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard arguments.contains(resetStoreArgument) else { return }
        let directory = CoreDataStack.storesDirectory()
        let stores = ["private.sqlite", "shared.sqlite"].flatMap { name in
            ["", "-wal", "-shm"].map { directory.appendingPathComponent(name + $0) }
        }
        _ = StoreReset.removeFiles(at: stores)
        let keychain = KeychainStore()
        let keys = [
            MemberIdentity.appleUserIDKey,
            AnonymousIdentity.storageKey,
            AppEnvironment.sessionTokenKey,
            AppEnvironment.appleIdentityTokenKey,
            AppEnvironment.appleAuthorizationCodeKey,
            AppEnvironment.appleRefreshTokenKey,
        ]
        for key in keys {
            try? keychain.removeValue(for: key)
        }
        let defaults = UserDefaults.corbieShared
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
        DebugEntitlementOverride.store(.premium)
    }
}
#endif
