import Foundation

public final class AnonymousIdentity: @unchecked Sendable {
    public static let storageKey = "corbie.analytics.anonId"
    public static let shared = AnonymousIdentity()

    private let store: (any SecretStore)?
    private let make: @Sendable () -> String
    private let lock = NSLock()
    private var cached: String?

    public init(store: (any SecretStore)? = KeychainStore(), make: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() }) {
        self.store = store
        self.make = make
    }

    public static func inMemory(value: String? = nil) -> AnonymousIdentity {
        let identity = AnonymousIdentity(store: nil)
        if let value { identity.cached = value }
        return identity
    }

    public var current: String {
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }
        if let stored = try? store?.string(for: AnonymousIdentity.storageKey),
           stored.isEmpty == false {
            cached = stored
            return stored
        }
        let fresh = make()
        try? store?.setString(fresh, for: AnonymousIdentity.storageKey)
        cached = fresh
        return fresh
    }

    public func reset() {
        lock.lock()
        cached = nil
        lock.unlock()
        try? store?.removeValue(for: AnonymousIdentity.storageKey)
    }
}
