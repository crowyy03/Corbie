import Foundation

public protocol MonetizationSource: Sendable {
    var isEnabled: Bool { get }
    func refresh() async -> Bool
}

public struct ConfigPayload: Sendable, Equatable, Codable {
    public let monetizationEnabled: Bool

    public init(monetizationEnabled: Bool) {
        self.monetizationEnabled = monetizationEnabled
    }
}

public struct MonetizationFlagStore: Sendable {
    public static let storageKey = "corbie.monetization.enabled"

    private let suiteName: String

    public init(suiteName: String = CorbieIdentifiers.appGroup) {
        self.suiteName = suiteName
    }

    public var fetchedValue: Bool? {
        defaults.object(forKey: MonetizationFlagStore.storageKey) as? Bool
    }

    public var isEnabled: Bool {
        #if DEBUG
        if let forced = DebugMonetizationOverride.stored(suiteName: suiteName) {
            return forced.isEnabled
        }
        #endif
        return fetchedValue ?? true
    }

    public func record(_ enabled: Bool) {
        defaults.set(enabled, forKey: MonetizationFlagStore.storageKey)
    }

    private var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}

public struct ServerMonetizationFlag: MonetizationSource {
    private let client: APIClient
    private let store: MonetizationFlagStore
    private let onChange: @Sendable () -> Void

    public init(
        client: APIClient,
        store: MonetizationFlagStore = MonetizationFlagStore(),
        onChange: @escaping @Sendable () -> Void = { WidgetReloadRequest.post() }
    ) {
        self.client = client
        self.store = store
        self.onChange = onChange
    }

    public var isEnabled: Bool { store.isEnabled }

    public func refresh() async -> Bool {
        if let payload = try? await client.config(), payload.monetizationEnabled != store.fetchedValue {
            store.record(payload.monetizationEnabled)
            onChange()
        }
        return store.isEnabled
    }
}
