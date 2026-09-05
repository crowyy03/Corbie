import Foundation
import Security

public struct KeychainStore: SecretStore {
    public static let service = CorbieIdentifiers.bundleID

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
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
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
        let query = baseQuery(for: key)
        let attributes: [String: Any] = [kSecValueData as String: value]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw CorbieError.auth("keychain update failed with status \(updateStatus)")
        }
        var insert = query
        insert[kSecValueData as String] = value
        insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw CorbieError.auth("keychain write failed with status \(addStatus)")
        }
    }

    public func removeValue(for key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CorbieError.auth("keychain delete failed with status \(status)")
        }
    }

    private func baseQuery(for key: String) -> [String: Any] {
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
