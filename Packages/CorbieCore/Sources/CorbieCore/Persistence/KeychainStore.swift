import Foundation
import os
import Security

public struct KeychainStore: SecretStore {
    public static let service = CorbieIdentifiers.bundleID

    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "keychain")

    private let service: String
    private let accessGroup: String?

    public init(service: String = KeychainStore.service, accessGroup: String? = KeychainStore.defaultAccessGroup) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public static var defaultAccessGroup: String? {
        #if os(iOS)
        return CorbieIdentifiers.appGroup
        #else
        return nil
        #endif
    }

    public func data(for key: String) throws -> Data? {
        var item: CFTypeRef?
        let status = run(key, "read") { query in
            var read = query
            read[kSecReturnData as String] = true
            read[kSecMatchLimit as String] = kSecMatchLimitOne
            return SecItemCopyMatching(read as CFDictionary, &item)
        }
        switch status {
        case errSecSuccess:
            return item as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw CorbieError.auth("keychain read failed with status \(status)")
        }
    }

    public func setData(_ value: Data, for key: String) throws {
        let status = run(key, "write") { query in
            let attributes: [String: Any] = [kSecValueData as String: value]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecItemNotFound else { return updateStatus }
            var insert = query
            insert[kSecValueData as String] = value
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            return SecItemAdd(insert as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw CorbieError.auth("keychain write failed with status \(status)")
        }
    }

    public func removeValue(for key: String) throws {
        let status = run(key, "delete") { query in
            SecItemDelete(query as CFDictionary)
        }
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CorbieError.auth("keychain delete failed with status \(status)")
        }
    }

    private func run(_ key: String, _ what: String, _ call: ([String: Any]) -> OSStatus) -> OSStatus {
        let status = call(baseQuery(for: key))
        guard status == errSecMissingEntitlement, let accessGroup else { return status }
        KeychainStore.log.error(
            """
            \(what, privacy: .public) of \(key, privacy: .public) was refused in \
            \(accessGroup, privacy: .public) with -34018, falling back to this process own keychain
            """
        )
        return call(baseQuery(for: key, accessGroup: nil))
    }

    private func baseQuery(for key: String) -> [String: Any] {
        baseQuery(for: key, accessGroup: accessGroup)
    }

    private func baseQuery(for key: String, accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        #if os(macOS)
        query[kSecUseDataProtectionKeychain as String] = true
        #endif
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }
}
