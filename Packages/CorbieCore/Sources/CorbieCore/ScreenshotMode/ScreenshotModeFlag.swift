#if DEBUG
import Foundation

public struct ScreenshotModeFlag: @unchecked Sendable {
    public enum LaunchRequest: String, Sendable, Equatable {
        case on
        case off
    }

    public static let sessionKey = "screenshotMode.session"
    public static let launchArgument = "-corbie-screenshot-mode"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .corbieShared) {
        self.defaults = defaults
    }

    public var session: String? {
        guard let value = defaults.string(forKey: ScreenshotModeFlag.sessionKey), value.isEmpty == false else {
            return nil
        }
        return value
    }

    public var isOn: Bool { session != nil }

    public func turnOn(session: String) {
        defaults.set(session, forKey: ScreenshotModeFlag.sessionKey)
    }

    public func turnOff() {
        defaults.removeObject(forKey: ScreenshotModeFlag.sessionKey)
    }

    public static func newSession() -> String {
        UUID().uuidString.lowercased()
    }

    public static func launchRequest(in arguments: [String]) -> LaunchRequest? {
        guard let flag = arguments.firstIndex(of: launchArgument), flag + 1 < arguments.count else { return nil }
        return LaunchRequest(rawValue: arguments[flag + 1].lowercased())
    }
}
#endif
