import Foundation
import Testing
@testable import CorbieCore

@Suite struct BusyIntervalRepositoryTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    private func hours(_ from: Double, _ to: Double) -> BusyIntervalDraft {
        BusyIntervalDraft(
            startAt: start.addingTimeInterval(from * 3600),
            endAt: start.addingTimeInterval(to * 3600)
        )
    }

    @Test func replaceSwapsEverythingThisMemberPublishedFromThatSource() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.busyIntervals
        _ = try await repository.replace(
            spaceId: world.space.id,
            memberId: world.me.id,
            source: .device,
            intervals: [hours(0, 1), hours(2, 3)]
        )
        let second = try await repository.replace(
            spaceId: world.space.id,
            memberId: world.me.id,
            source: .device,
            intervals: [hours(5, 6)]
        )
        #expect(second.count == 1)
        let stored = try world.count(BusyInterval.entityName)
        #expect(stored == 1)
        #expect(second.first?.source == .device)
        #expect(second.first?.memberId == world.me.id)
    }

    @Test func replaceLeavesTheOtherMemberAndTheOtherSourceAlone() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.busyIntervals
        _ = try await repository.replace(
            spaceId: world.space.id,
            memberId: world.partner.id,
            source: .device,
            intervals: [hours(0, 1)]
        )
        _ = try await repository.replace(
            spaceId: world.space.id,
            memberId: world.me.id,
            source: .corbie,
            intervals: [hours(1, 2)]
        )
        _ = try await repository.replace(
            spaceId: world.space.id,
            memberId: world.me.id,
            source: .device,
            intervals: [hours(2, 3)]
        )
        let all = try await repository.intervals(
            spaceId: world.space.id,
            from: start.addingTimeInterval(-3600),
            to: start.addingTimeInterval(24 * 3600)
        )
        #expect(all.count == 3)
        #expect(all.map(\.startAt) == all.map(\.startAt).sorted())
    }

    @Test func theWindowKeepsOnlyOverlappingIntervals() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.busyIntervals
        _ = try await repository.replace(
            spaceId: world.space.id,
            memberId: world.me.id,
            source: .device,
            intervals: [hours(0, 1), hours(4, 5), hours(10, 11)]
        )
        let window = try await repository.intervals(
            spaceId: world.space.id,
            from: start.addingTimeInterval(3.5 * 3600),
            to: start.addingTimeInterval(6 * 3600)
        )
        #expect(window.count == 1)
        #expect(window.first?.duration == 3600)
    }

    @Test func anIntervalThatEndsBeforeItStartsIsRejected() async throws {
        let world = try await TestWorld.make()
        await #expect(throws: CorbieError.invalidInput("busy interval ends before it starts")) {
            _ = try await world.repositories.busyIntervals.replace(
                spaceId: world.space.id,
                memberId: world.me.id,
                source: .device,
                intervals: [BusyIntervalDraft(startAt: start, endAt: start)]
            )
        }
    }

    @Test func deleteAllClearsOneSourceAndPurgeDropsThePast() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.busyIntervals
        _ = try await repository.replace(
            spaceId: world.space.id,
            memberId: world.me.id,
            source: .device,
            intervals: [hours(0, 1)]
        )
        _ = try await repository.replace(
            spaceId: world.space.id,
            memberId: world.me.id,
            source: .corbie,
            intervals: [hours(20, 21)]
        )
        try await repository.deleteAll(memberId: world.me.id, source: .device)
        let afterDelete = try world.count(BusyInterval.entityName)
        #expect(afterDelete == 1)

        try await repository.purge(before: start.addingTimeInterval(30 * 3600))
        let afterPurge = try world.count(BusyInterval.entityName)
        #expect(afterPurge == 0)
    }

    @Test func deletingTheSpaceTakesItsBusyIntervals() async throws {
        let world = try await TestWorld.make()
        _ = try await world.repositories.busyIntervals.replace(
            spaceId: world.space.id,
            memberId: world.me.id,
            source: .device,
            intervals: [hours(0, 1)]
        )
        try await world.repositories.spaces.delete(id: world.space.id)
        let left = try world.count(BusyInterval.entityName)
        #expect(left == 0)
    }
}
