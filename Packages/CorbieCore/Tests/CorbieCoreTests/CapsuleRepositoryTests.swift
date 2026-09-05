import Foundation
import Testing
@testable import CorbieCore

@Suite struct CapsuleRepositoryTests {
    private let now = Date(timeIntervalSince1970: 1_757_000_000)

    @Test func capsuleOpensOnlyOnItsDate() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.capsules
        let opensAt = now.addingTimeInterval(86_400)
        let capsule = try await repository.create(
            CapsuleDraft(
                spaceId: world.space.id,
                authorMemberId: world.me.id,
                recipientMemberId: world.partner.id,
                title: "First year",
                body: "See you on the other side",
                opensAt: opensAt
            ),
            now: now
        )
        #expect(capsule.isUnlocked(at: now) == false)
        #expect(capsule.isEditable(at: now))

        await #expect(throws: CorbieError.invalidInput("capsule is still sealed")) {
            _ = try await repository.markOpened(capsuleId: capsule.id, memberId: world.partner.id, at: now)
        }

        let opened = try await repository.markOpened(
            capsuleId: capsule.id,
            memberId: world.partner.id,
            at: opensAt
        )
        #expect(opened.openedAt == opensAt)
        #expect(opened.openedByMemberIds == [world.partner.id])
        #expect(opened.isReadByBoth == false)

        let both = try await repository.markOpened(
            capsuleId: capsule.id,
            memberId: world.me.id,
            at: opensAt.addingTimeInterval(60)
        )
        #expect(both.isReadByBoth)
        #expect(both.openedAt == opensAt)
    }

    @Test func openingTwiceDoesNotDuplicateTheReader() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.capsules
        let opensAt = now.addingTimeInterval(3600)
        let capsule = try await repository.create(
            CapsuleDraft(spaceId: world.space.id, title: "Note", body: "Hello", opensAt: opensAt),
            now: now
        )
        _ = try await repository.markOpened(capsuleId: capsule.id, memberId: world.me.id, at: opensAt)
        let again = try await repository.markOpened(capsuleId: capsule.id, memberId: world.me.id, at: opensAt)
        #expect(again.openedByMemberIds == [world.me.id])
    }

    @Test func authorCanEditUntilItOpens() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.capsules
        let opensAt = now.addingTimeInterval(86_400)
        var capsule = try await repository.create(
            CapsuleDraft(spaceId: world.space.id, title: "Draft", body: "One", opensAt: opensAt),
            now: now
        )
        capsule.body = "Two"
        let edited = try await repository.update(capsule, now: now)
        #expect(edited.body == "Two")

        await #expect(throws: CorbieError.invalidInput("capsule is already open")) {
            _ = try await repository.update(capsule, now: opensAt)
        }
    }

    @Test func capsuleCannotOpenInThePast() async throws {
        let world = try await TestWorld.make()
        await #expect(throws: CorbieError.invalidInput("capsule opens in the past")) {
            _ = try await world.repositories.capsules.create(
                CapsuleDraft(
                    spaceId: world.space.id,
                    title: "Late",
                    body: "Body",
                    opensAt: now.addingTimeInterval(-60)
                ),
                now: now
            )
        }
    }
}
