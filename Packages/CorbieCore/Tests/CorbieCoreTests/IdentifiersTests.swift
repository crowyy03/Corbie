import Testing
@testable import CorbieCore

@Suite struct IdentifiersTests {
    @Test func appGroupMatchesBundlePrefix() {
        #expect(CorbieIdentifiers.appGroup == "group." + CorbieIdentifiers.bundleID)
    }
}
