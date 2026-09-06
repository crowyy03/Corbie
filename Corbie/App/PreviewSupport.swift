#if DEBUG
import CorbieCore
import Foundation

enum PreviewNames {
    static let member = "Alex"
    static let partner = "Sofia"
}

final class InMemorySecretStore: SecretStore, @unchecked Sendable {
    private var values: [String: Data] = [:]
    private let lock = NSLock()

    func data(for key: String) throws -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func setData(_ value: Data, for key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values[key] = value
    }

    func removeValue(for key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values[key] = nil
    }
}

struct PreviewNotificationClient: NotificationCenterClient {
    func authorizationStatus() async -> NotificationAuthorization { .notDetermined }
    func requestAuthorization() async throws -> Bool { true }
    func registerCategories(_ categories: [NotificationCategoryDescriptor]) async {}
    func pendingIdentifiers() async -> [String] { [] }
    func add(_ request: CorbieNotificationRequest) async throws {}
    func removePending(identifiers: [String]) async {}
}
#endif
