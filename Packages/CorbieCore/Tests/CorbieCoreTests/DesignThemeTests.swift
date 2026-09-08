import Foundation
import SwiftUI
import Testing
@testable import CorbieCore

@Suite struct DesignThemeTests {
    private func makeSuite() -> (UserDefaults, String) {
        let name = "corbie.tests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: name) else {
            return (.standard, name)
        }
        return (defaults, name)
    }

    private func removeSuite(_ defaults: UserDefaults, _ name: String) {
        defaults.removePersistentDomain(forName: name)
    }

    @Test func firstLaunchFollowsTheSystemWithIceAndDeep() {
        let (defaults, name) = makeSuite()
        defer { removeSuite(defaults, name) }

        let settings = ThemeStore(defaults: defaults).settings
        #expect(settings.followsSystem)
        #expect(settings.lightTheme == .ice)
        #expect(settings.darkTheme == .deep)
    }

    @Test func everySettingSurvivesAReload() {
        let (defaults, name) = makeSuite()
        defer { removeSuite(defaults, name) }

        let store = ThemeStore(defaults: defaults)
        store.save(ThemeSettings(theme: .sage, followsSystem: false, lightTheme: .sage, darkTheme: .deep))

        let reloaded = ThemeStore(defaults: defaults).settings
        #expect(reloaded.theme == .sage)
        #expect(reloaded.followsSystem == false)
        #expect(reloaded.lightTheme == .sage)
        #expect(reloaded.darkTheme == .deep)
    }

    @Test func anUnknownStoredNameFallsBackToTheFirstLaunchValue() {
        let (defaults, name) = makeSuite()
        defer { removeSuite(defaults, name) }

        defaults.set("sepia", forKey: ThemeStore.Key.theme)
        #expect(ThemeStore(defaults: defaults).settings.theme == .ice)
    }

    @Test func followingTheSystemPicksTheLightOrDarkChoice() {
        let settings = ThemeSettings(theme: .sage, followsSystem: true, lightTheme: .sand, darkTheme: .deep)
        #expect(settings.resolved(for: .light) == .sand)
        #expect(settings.resolved(for: .dark) == .deep)
        #expect(settings.preferredColorScheme == nil)
    }

    @Test func aFixedThemeIgnoresTheSystemAndForcesTheScheme() {
        let light = ThemeSettings(theme: .sage, followsSystem: false, lightTheme: .sand, darkTheme: .deep)
        #expect(light.resolved(for: .dark) == .sage)
        #expect(light.preferredColorScheme == ColorScheme.light)

        let dark = ThemeSettings(theme: .deep, followsSystem: false, lightTheme: .sand, darkTheme: .deep)
        #expect(dark.resolved(for: .light) == .deep)
        #expect(dark.preferredColorScheme == ColorScheme.dark)
    }

    @MainActor
    @Test func theProviderWritesThroughToTheStore() {
        let (defaults, name) = makeSuite()
        defer { removeSuite(defaults, name) }

        let provider = ThemeProvider(store: ThemeStore(defaults: defaults))
        provider.systemScheme = .dark
        #expect(provider.preferredColorScheme == nil)
        #expect(provider.activeTheme == .deep)

        provider.setFollowsSystem(false)
        provider.setTheme(.sage)
        #expect(provider.preferredColorScheme == ColorScheme.light)
        #expect(provider.activeTheme == .sage)

        #expect(ThemeStore(defaults: defaults).settings.theme == .sage)
    }

    @MainActor
    @Test func theProviderKeepsTheLightAndDarkChoicesApart() {
        let (defaults, name) = makeSuite()
        defer { removeSuite(defaults, name) }

        let provider = ThemeProvider(store: ThemeStore(defaults: defaults))
        provider.setLightTheme(.sage)
        provider.setDarkTheme(.deep)
        provider.systemScheme = .light
        #expect(provider.activeTheme == .sage)
        provider.systemScheme = .dark
        #expect(provider.activeTheme == .deep)
    }
}
