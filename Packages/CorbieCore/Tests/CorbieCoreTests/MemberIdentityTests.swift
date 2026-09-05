import Foundation
import Testing
@testable import CorbieCore

@Suite struct MemberIdentityTests {
    @Test func identityResolvesTheStoredMember() async throws {
        let world = try await TestWorld.make()
        let identity = MemberIdentity(store: InMemorySecretStore())
        #expect(identity.currentAppleUserID == nil)
        #expect(try await identity.currentMember(in: world.controller.stack) == nil)

        try identity.setAppleUserID("apple-partner")
        #expect(identity.currentAppleUserID == "apple-partner")
        let member = try await identity.currentMember(in: world.controller.stack)
        #expect(member?.id == world.partner.id)

        try identity.clear()
        #expect(identity.currentAppleUserID == nil)
    }

    @Test func emptyIdentifierIsRejected() throws {
        let identity = MemberIdentity(store: InMemorySecretStore())
        #expect(throws: CorbieError.invalidInput("apple user id is empty")) {
            try identity.setAppleUserID("  ")
        }
    }

    @Test func identifierIsTrimmed() throws {
        let identity = MemberIdentity(store: InMemorySecretStore())
        try identity.setAppleUserID("  001.abc  ")
        #expect(identity.currentAppleUserID == "001.abc")
    }
}
