import Foundation
import os

public struct StorageHealth: Sendable, Equatable {
    public let appGroupPath: String?
    public let defaultsRoundTrip: Bool
    public let keychainStatus: OSStatus
    public let keychainAccessGroup: String?

    public init(
        appGroupPath: String?,
        defaultsRoundTrip: Bool,
        keychainStatus: OSStatus,
        keychainAccessGroup: String?
    ) {
        self.appGroupPath = appGroupPath
        self.defaultsRoundTrip = defaultsRoundTrip
        self.keychainStatus = keychainStatus
        self.keychainAccessGroup = keychainAccessGroup
    }

    public var isHealthy: Bool {
        appGroupPath != nil && defaultsRoundTrip && keychainStatus == errSecSuccess
    }

    public var summary: String {
        let container = appGroupPath ?? "no app group container"
        let defaults = defaultsRoundTrip ? "defaults ok" : "defaults unreadable"
        let keychain: String
        switch keychainStatus {
        case errSecSuccess:
            keychain = "keychain ok in \(keychainAccessGroup ?? "the default group")"
        case errSecMissingEntitlement:
            keychain = "keychain refused \(keychainAccessGroup ?? "the default group"), status -34018"
        default:
            keychain = "keychain failed with status \(keychainStatus)"
        }
        return "\(container), \(defaults), \(keychain)"
    }
}

public enum StorageProbe {
    public static let defaultsKey = "corbie.storage.probe"
    public static let keychainKey = "corbie.storage.probe"

    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "storage")

    public static func run(
        process: String,
        appGroup: String = CorbieIdentifiers.appGroup,
        accessGroup: String? = KeychainStore.defaultAccessGroup
    ) -> StorageHealth {
        let health = StorageHealth(
            appGroupPath: containerPath(appGroup),
            defaultsRoundTrip: defaultsRoundTrip(appGroup),
            keychainStatus: keychainStatus(accessGroup),
            keychainAccessGroup: accessGroup
        )
        if health.isHealthy {
            log.notice("\(process, privacy: .public) storage: \(health.summary, privacy: .public)")
        } else {
            log.error("\(process, privacy: .public) storage: \(health.summary, privacy: .public)")
        }
        return health
    }

    private static func containerPath(_ appGroup: String) -> String? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?.path
    }

    private static func defaultsRoundTrip(_ appGroup: String) -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroup) else { return false }
        let written = UUID().uuidString
        defaults.set(written, forKey: defaultsKey)
        let read = defaults.string(forKey: defaultsKey)
        defaults.removeObject(forKey: defaultsKey)
        return read == written
    }

    private static func keychainStatus(_ accessGroup: String?) -> OSStatus {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: KeychainStore.service,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: Data("probe".utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        #if os(macOS)
        query[kSecUseDataProtectionKeychain as String] = true
        #endif
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            SecItemDelete(query as CFDictionary)
        }
        return status
    }
}
