import Foundation
import Testing
@testable import CorbieCore

@Suite struct WishRepositoryTests {
    @Test func ownerFilterSeparatesPartnerFromMe() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.wishes
        let spaceId = world.space.id
        _ = try await repository.create(
            WishDraft(
                spaceId: spaceId,
                ownerMemberId: world.partner.id,
                addedByMemberId: world.me.id,
                title: "Headphones",
                price: 199,
                currency: "USD",
                priority: .must,
                source: .amazon
            )
        )
        _ = try await repository.create(
            WishDraft(
                spaceId: spaceId,
                ownerMemberId: world.me.id,
                addedByMemberId: world.me.id,
                title: "Running shoes"
            )
        )

        let theirs = try await repository.wishes(WishQuery(spaceId: spaceId, owner: .member(world.partner.id)))
        #expect(theirs.map(\.title) == ["Headphones"])
        #expect(theirs.first?.priority == .must)
        #expect(theirs.first?.source == .amazon)
        #expect(theirs.first?.price == 199)

        let mine = try await repository.wishes(WishQuery(spaceId: spaceId, owner: .member(world.me.id)))
        #expect(mine.map(\.title) == ["Running shoes"])

        let all = try await repository.wishes(WishQuery(spaceId: spaceId))
        #expect(all.count == 2)
    }

    @Test func fulfilledWishesLeaveTheActiveList() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.wishes
        let wish = try await repository.create(
            WishDraft(spaceId: world.space.id, ownerMemberId: world.me.id, title: "Kettle")
        )
        let at = Date(timeIntervalSince1970: 1_757_000_000)
        let fulfilled = try await repository.fulfil(wishId: wish.id, at: at)
        #expect(fulfilled.isFulfilled)
        #expect(fulfilled.fulfilledAt == at)

        let active = try await repository.wishes(WishQuery(spaceId: world.space.id))
        #expect(active.isEmpty)

        let gifted = try await repository.wishes(WishQuery(spaceId: world.space.id, fulfilled: true))
        #expect(gifted.map(\.id) == [wish.id])
    }

    @Test func wishNeedsATitleOrALink() async throws {
        let world = try await TestWorld.make()
        await #expect(throws: CorbieError.invalidInput("wish needs a title or a link")) {
            _ = try await world.repositories.wishes.create(
                WishDraft(spaceId: world.space.id, ownerMemberId: world.me.id, title: " ")
            )
        }
        let fromShareSheet = try await world.repositories.wishes.create(
            WishDraft(
                spaceId: world.space.id,
                ownerMemberId: world.partner.id,
                title: "",
                url: "https://example.com/item",
                source: .store,
                needsParse: true
            )
        )
        let pending = try await world.repositories.wishes.pendingParse(spaceId: world.space.id)
        #expect(pending.map(\.id) == [fromShareSheet.id])
    }

    @Test func localImageSurvivesTheRoundTrip() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.wishes
        let bytes = Data((0..<512).map { UInt8($0 % 251) })
        let wish = try await repository.create(
            WishDraft(spaceId: world.space.id, ownerMemberId: world.me.id, title: "Poster", localImage: bytes)
        )
        let stored = try #require(try await repository.wish(id: wish.id))
        #expect(stored.localImage == bytes)
    }
}
