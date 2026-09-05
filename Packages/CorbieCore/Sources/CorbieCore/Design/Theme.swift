import Foundation
import Observation
import SwiftUI

public enum ThemePreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension ThemePreference {
    static let storageKey = "corbie.design.themePreference"

    static func stored(in defaults: UserDefaults) -> ThemePreference {
        guard let raw = defaults.string(forKey: storageKey) else { return .system }
        return ThemePreference(rawValue: raw) ?? .system
    }

    func store(in defaults: UserDefaults) {
        defaults.set(rawValue, forKey: Self.storageKey)
    }
}

public extension UserDefaults {
    static var corbieShared: UserDefaults {
        UserDefaults(suiteName: CorbieIdentifiers.appGroup) ?? .standard
    }
}

@Observable @MainActor
public final class ThemeStore {
    public private(set) var preference: ThemePreference

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .corbieShared) {
        self.defaults = defaults
        preference = ThemePreference.stored(in: defaults)
    }

    public var preferredColorScheme: ColorScheme? {
        preference.colorScheme
    }

    public func setPreference(_ newPreference: ThemePreference) {
        preference = newPreference
        newPreference.store(in: defaults)
    }
}
