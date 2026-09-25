import Foundation

public struct DeviceEntitlementSnapshot: Sendable, Equatable {
    public let environment: StoreEnvironment
    public let premiumUntil: Date

    public init(environment: StoreEnvironment, premiumUntil: Date) {
        self.environment = environment
        self.premiumUntil = premiumUntil
    }
}

public struct DeviceEntitlementStore: @unchecked Sendable {
    public static let keyPrefix = "corbie.entitlement.device."
    public static let openEndedLifetime: TimeInterval = 24 * 60 * 60

    private static let environmentField = "environment"
    private static let untilField = "until"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .corbieShared) {
        self.defaults = defaults
    }

    @discardableResult
    public func record(_ state: EntitlementState, spaceId: UUID, environment: StoreEnvironment, now: Date) -> Bool {
        let key = DeviceEntitlementStore.keyPrefix + spaceId.uuidString
        let before = defaults.dictionary(forKey: key)
        guard state.isPremium else {
            defaults.removeObject(forKey: key)
            return before != nil
        }
        let until = state.expiresAt ?? now.addingTimeInterval(DeviceEntitlementStore.openEndedLifetime)
        let entry: [String: Any] = [
            DeviceEntitlementStore.environmentField: environment.rawValue,
            DeviceEntitlementStore.untilField: until.timeIntervalSince1970,
        ]
        defaults.set(entry, forKey: key)
        return before?[DeviceEntitlementStore.environmentField] as? String != environment.rawValue
            || before?[DeviceEntitlementStore.untilField] as? TimeInterval != until.timeIntervalSince1970
    }

    public func snapshot(spaceId: UUID, at moment: Date) -> DeviceEntitlementSnapshot? {
        guard let entry = defaults.dictionary(forKey: DeviceEntitlementStore.keyPrefix + spaceId.uuidString),
              let raw = entry[DeviceEntitlementStore.environmentField] as? String,
              let environment = StoreEnvironment(rawValue: raw),
              let until = entry[DeviceEntitlementStore.untilField] as? TimeInterval,
              Date(timeIntervalSince1970: until) > moment
        else { return nil }
        return DeviceEntitlementSnapshot(environment: environment, premiumUntil: Date(timeIntervalSince1970: until))
    }
}
