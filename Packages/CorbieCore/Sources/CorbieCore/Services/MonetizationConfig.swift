import Foundation

public protocol MonetizationSource: Sendable {
    var isEnabled: Bool { get }
    var freeDays: Int { get }
    func refresh() async -> Bool
}

public struct ConfigPayload: Sendable, Equatable, Codable {
    public let monetizationV2Enabled: Bool
    public let freeDays: Int

    public init(monetizationV2Enabled: Bool, freeDays: Int) {
        self.monetizationV2Enabled = monetizationV2Enabled
        self.freeDays = freeDays
    }
}

public struct MonetizationConfigStore: Sendable {
    public static let enabledKey = "corbie.monetization.v2.enabled"
    public static let freeDaysKey = "corbie.monetization.freeDays"

    private let suiteName: String

    public init(suiteName: String = CorbieIdentifiers.appGroup) {
        self.suiteName = suiteName
    }

    public var fetchedValue: Bool? {
        defaults.object(forKey: MonetizationConfigStore.enabledKey) as? Bool
    }

    public var fetchedFreeDays: Int? {
        defaults.object(forKey: MonetizationConfigStore.freeDaysKey) as? Int
    }

    public var isEnabled: Bool {
        #if DEBUG
        if let forced = DebugMonetizationOverride.stored(suiteName: suiteName) {
            return forced.isEnabled
        }
        #endif
        return fetchedValue ?? true
    }

    public var freeDays: Int {
        #if DEBUG
        if DebugFreeWindowOverride.stored(suiteName: suiteName) == .ended {
            return 0
        }
        #endif
        return fetchedFreeDays ?? FreeWindow.defaultDays
    }

    public func freeWindow(for space: SpaceDTO, calendar: Calendar) -> FreeWindow? {
        FreeWindow(spaceCreatedAt: space.createdAt, days: freeDays, calendar: calendar)
    }

    public func record(_ enabled: Bool) {
        defaults.set(enabled, forKey: MonetizationConfigStore.enabledKey)
    }

    public func record(freeDays: Int) {
        defaults.set(freeDays, forKey: MonetizationConfigStore.freeDaysKey)
    }

    private var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }
}

public struct ServerMonetizationConfig: MonetizationSource {
    private let client: APIClient
    private let store: MonetizationConfigStore
    private let onChange: @Sendable () -> Void

    public init(
        client: APIClient,
        store: MonetizationConfigStore = MonetizationConfigStore(),
        onChange: @escaping @Sendable () -> Void = { WidgetReloadRequest.post() }
    ) {
        self.client = client
        self.store = store
        self.onChange = onChange
    }

    public var isEnabled: Bool { store.isEnabled }

    public var freeDays: Int { store.freeDays }

    public func refresh() async -> Bool {
        if let payload = try? await client.config(),
           payload.monetizationV2Enabled != store.fetchedValue || payload.freeDays != store.fetchedFreeDays {
            store.record(payload.monetizationV2Enabled)
            store.record(freeDays: payload.freeDays)
            onChange()
        }
        return store.isEnabled
    }
}
