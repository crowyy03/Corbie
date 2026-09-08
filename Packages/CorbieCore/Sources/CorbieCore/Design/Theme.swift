import Foundation
import Observation
import SwiftUI

public struct ThemeSettings: Sendable, Equatable {
    public var theme: CorbieTheme
    public var followsSystem: Bool
    public var lightTheme: CorbieTheme
    public var darkTheme: CorbieTheme

    public static let firstLaunch = ThemeSettings(
        theme: .sand,
        followsSystem: true,
        lightTheme: .sand,
        darkTheme: .deep
    )

    public init(theme: CorbieTheme, followsSystem: Bool, lightTheme: CorbieTheme, darkTheme: CorbieTheme) {
        self.theme = theme
        self.followsSystem = followsSystem
        self.lightTheme = lightTheme
        self.darkTheme = darkTheme
    }

    public func resolved(for colorScheme: ColorScheme) -> CorbieTheme {
        guard followsSystem else { return theme }
        return colorScheme == .dark ? darkTheme : lightTheme
    }

    public var preferredColorScheme: ColorScheme? {
        guard followsSystem == false else { return nil }
        return theme.isDark ? .dark : .light
    }
}

public struct ThemeStore {
    public enum Key {
        public static let theme = "theme"
        public static let autoTheme = "autoTheme"
        public static let autoLightTheme = "autoLightTheme"
        public static let autoDarkTheme = "autoDarkTheme"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .corbieShared) {
        self.defaults = defaults
    }

    public var settings: ThemeSettings {
        let followsSystem = defaults.object(forKey: Key.autoTheme) == nil
            ? ThemeSettings.firstLaunch.followsSystem
            : defaults.bool(forKey: Key.autoTheme)
        return ThemeSettings(
            theme: theme(Key.theme) ?? ThemeSettings.firstLaunch.theme,
            followsSystem: followsSystem,
            lightTheme: theme(Key.autoLightTheme) ?? ThemeSettings.firstLaunch.lightTheme,
            darkTheme: theme(Key.autoDarkTheme) ?? ThemeSettings.firstLaunch.darkTheme
        )
    }

    public func save(_ settings: ThemeSettings) {
        defaults.set(settings.theme.rawValue, forKey: Key.theme)
        defaults.set(settings.followsSystem, forKey: Key.autoTheme)
        defaults.set(settings.lightTheme.rawValue, forKey: Key.autoLightTheme)
        defaults.set(settings.darkTheme.rawValue, forKey: Key.autoDarkTheme)
    }

    private func theme(_ key: String) -> CorbieTheme? {
        guard let raw = defaults.string(forKey: key) else { return nil }
        return CorbieTheme(rawValue: raw)
    }
}

public extension UserDefaults {
    static var corbieShared: UserDefaults {
        UserDefaults(suiteName: CorbieIdentifiers.appGroup) ?? .standard
    }
}

@Observable @MainActor
public final class ThemeProvider {
    public private(set) var settings: ThemeSettings
    public var systemScheme: ColorScheme = .light

    @ObservationIgnored private let store: ThemeStore

    public init(store: ThemeStore = ThemeStore()) {
        self.store = store
        settings = store.settings
    }

    public var preferredColorScheme: ColorScheme? {
        settings.preferredColorScheme
    }

    public var activeTheme: CorbieTheme {
        settings.resolved(for: systemScheme)
    }

    public func setFollowsSystem(_ follows: Bool) {
        apply { $0.followsSystem = follows }
    }

    public func setTheme(_ theme: CorbieTheme) {
        apply { $0.theme = theme }
    }

    public func setLightTheme(_ theme: CorbieTheme) {
        apply { $0.lightTheme = theme }
    }

    public func setDarkTheme(_ theme: CorbieTheme) {
        apply { $0.darkTheme = theme }
    }

    private func apply(_ change: (inout ThemeSettings) -> Void) {
        var updated = settings
        change(&updated)
        guard updated != settings else { return }
        settings = updated
        store.save(updated)
    }
}

private struct PaletteEnvironmentKey: EnvironmentKey {
    static let defaultValue = CorbieTheme.sand.palette
}

private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue = CorbieTheme.sand
}

public extension EnvironmentValues {
    var palette: ThemePalette {
        get { self[PaletteEnvironmentKey.self] }
        set { self[PaletteEnvironmentKey.self] = newValue }
    }

    var theme: CorbieTheme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

public extension View {
    func corbieTheme(_ theme: CorbieTheme) -> some View {
        environment(\.theme, theme)
            .environment(\.palette, theme.palette)
    }
}
