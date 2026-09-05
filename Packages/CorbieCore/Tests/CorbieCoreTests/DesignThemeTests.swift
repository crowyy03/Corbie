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

    @Test func defaultsToSystemWhenNothingStored() {
        let (defaults, name) = makeSuite()
        defer { removeSuite(defaults, name) }

        #expect(ThemePreference.stored(in: defaults) == .system)
    }

    @Test func persistenceRoundTrip() {
        let (defaults, name) = makeSuite()
        defer { removeSuite(defaults, name) }

        for preference in ThemePreference.allCases {
            preference.store(in: defaults)
            #expect(ThemePreference.stored(in: defaults) == preference)
        }
    }

    @Test func unknownStoredValueFallsBackToSystem() {
        let (defaults, name) = makeSuite()
        defer { removeSuite(defaults, name) }

        defaults.set("sepia", forKey: ThemePreference.storageKey)
        #expect(ThemePreference.stored(in: defaults) == .system)
    }

    @Test func colorSchemeMapping() {
        #expect(ThemePreference.system.colorScheme == nil)
        #expect(ThemePreference.light.colorScheme == ColorScheme.light)
        #expect(ThemePreference.dark.colorScheme == ColorScheme.dark)
    }

    @MainActor
    @Test func storeWritesAndReloadsPreference() {
        let (defaults, name) = makeSuite()
        defer { removeSuite(defaults, name) }

        let store = ThemeStore(defaults: defaults)
        #expect(store.preference == .system)
        #expect(store.preferredColorScheme == nil)

        store.setPreference(.dark)
        #expect(store.preferredColorScheme == ColorScheme.dark)

        let reloaded = ThemeStore(defaults: defaults)
        #expect(reloaded.preference == .dark)
    }
}
