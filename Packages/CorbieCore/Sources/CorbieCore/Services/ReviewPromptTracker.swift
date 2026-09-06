import Foundation

public struct ReviewPromptTracker: @unchecked Sendable {
    public static let minimumJointActions = 3
    public static let minimumDaysSinceInstall = 5
    public static let installedAtKey = "corbie.review.installedAt"
    public static let jointActionCountKey = "corbie.review.jointActions"
    public static let requestedAtKey = "corbie.review.requestedAt"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .corbieShared) {
        self.defaults = defaults
    }

    public var installedAt: Date? {
        defaults.object(forKey: Self.installedAtKey) as? Date
    }

    public var jointActionCount: Int {
        defaults.integer(forKey: Self.jointActionCountKey)
    }

    public var requestedAt: Date? {
        defaults.object(forKey: Self.requestedAtKey) as? Date
    }

    public func recordLaunch(now: Date = Date()) {
        guard installedAt == nil else { return }
        defaults.set(now, forKey: Self.installedAtKey)
    }

    public func recordJointAction() {
        defaults.set(jointActionCount + 1, forKey: Self.jointActionCountKey)
    }

    public func shouldRequest(now: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard requestedAt == nil, let installedAt else { return false }
        guard jointActionCount >= Self.minimumJointActions else { return false }
        let days = calendar.dateComponents([.day], from: installedAt, to: now).day ?? 0
        return days >= Self.minimumDaysSinceInstall
    }

    public func markRequested(now: Date = Date()) {
        defaults.set(now, forKey: Self.requestedAtKey)
    }
}
