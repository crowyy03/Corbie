#if DEBUG
import CorbieCore
import Foundation

enum DebugLaunch {
    static let resetStoreArgument = "-corbie-reset-store"

    static func resetStoreIfRequested(arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard arguments.contains(resetStoreArgument) else { return }
        let directory = CoreDataStack.storesDirectory()
        let stores = ["private.sqlite", "shared.sqlite"].flatMap { name in
            ["", "-wal", "-shm"].map { directory.appendingPathComponent(name + $0) }
        }
        _ = StoreReset.removeFiles(at: stores)
        let keychain = KeychainStore()
        for key in [MemberIdentity.appleUserIDKey, AppEnvironment.sessionTokenKey, AppEnvironment.appleIdentityTokenKey] {
            try? keychain.removeValue(for: key)
        }
        let defaults = UserDefaults.corbieShared
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
    }
}
#endif
