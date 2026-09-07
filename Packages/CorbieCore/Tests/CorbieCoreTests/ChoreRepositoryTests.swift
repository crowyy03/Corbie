import Foundation
import Testing
@testable import CorbieCore

@Suite struct ChoreRepositoryTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "UTC")

    private func world() async throws -> (TestWorld, CoreDataChoreRepository) {
        let world = try await TestWorld.make()
        let repository = CoreDataChoreRepository(
            stack: world.controller.stack,
            catalog: .bundled,
            locale: Locale(identifier: "en_US")
        )
        return (world, repository)
    }

    private func rateEverything(
        _ repository: CoreDataChoreRepository,
        set: ChoreSetDTO,
        memberId: UUID,
        verdict: (Int) -> ChoreVerdict,
        at date: Date
    ) async throws -> ChoreSetDTO {
        var latest = set
        for (index, item) in set.includedItems.enumerated() {
            latest = try await repository.rate(
                itemId: item.id,
                memberId: memberId,
                verdict: verdict(index),
                at: date
            )
        }
        return latest
    }

    private func revealed(_ world: TestWorld, _ repository: CoreDataChoreRepository) async throws -> ChoreSetDTO {
        let now = DomainClock.date("2026-09-07 10:00", in: calendar)
        let set = try await repository.startSet(spaceId: world.space.id, catalogIds: [], memberId: world.me.id, at: now)
        _ = try await rateEverything(
            repository,
            set: set,
            memberId: world.me.id,
            verdict: { $0.isMultiple(of: 2) ? .like : .hate },
            at: now
        )
        _ = try await rateEverything(
            repository,
            set: set,
            memberId: world.partner.id,
            verdict: { $0.isMultiple(of: 2) ? .hate : .like },
            at: now
        )
        return try await repository.reveal(setId: set.id, at: now)
    }

    @Test func theListStartsFromTheCatalogAndOnlyOneSetIsOpenAtATime() async throws {
        let (world, repository) = try await world()
        let now = DomainClock.date("2026-09-07 10:00", in: calendar)
        let set = try await repository.startSet(
            spaceId: world.space.id,
            catalogIds: [],
            memberId: world.me.id,
            at: now
        )
        #expect(set.status == .building)
        #expect(set.items.count == ChoreCatalog.bundled.preselectedIds.count)
        #expect(set.items.allSatisfy { $0.isIncluded })
        #expect(set.items.first?.title == "Wash the dishes")
        #expect(set.canStartRating)

        let again = try await repository.startSet(
            spaceId: world.space.id,
            catalogIds: ["c002"],
            memberId: world.partner.id,
            at: now
        )
        #expect(again.id == set.id)
        #expect(again.items.count == set.items.count)
        let active = try await repository.activeSet(spaceId: world.space.id, viewerMemberId: world.me.id)
        #expect(active?.id == set.id)
    }

    @Test func bothOfYouCanEditTheListBeforeRating() async throws {
        let (world, repository) = try await world()
        let now = DomainClock.date("2026-09-07 10:00", in: calendar)
        let set = try await repository.startSet(spaceId: world.space.id, catalogIds: ["c001", "c002"], memberId: world.me.id, at: now)
        let withCustom = try await repository.addItem(
            setId: set.id,
            draft: ChoreItemDraft(title: "  Water the balcony  ", frequency: .fewTimesAWeek, addedByMemberId: world.partner.id)
        )
        let custom = try #require(withCustom.items.last)
        #expect(custom.title == "Water the balcony")
        #expect(custom.isCustom)
        #expect(custom.frequency == .fewTimesAWeek)

        let fromCatalog = try await repository.addItem(
            setId: set.id,
            draft: ChoreItemDraft(catalogId: "c010", title: "", addedByMemberId: world.partner.id)
        )
        #expect(fromCatalog.items.contains { $0.catalogId == "c010" })

        let excluded = try await repository.setIncluded(itemId: custom.id, isIncluded: false)
        #expect(excluded.includedItems.contains { $0.id == custom.id } == false)
        let slower = try await repository.setFrequency(itemId: custom.id, frequency: .monthly)
        #expect(slower.items.first { $0.id == custom.id }?.frequency == .monthly)
        let removed = try await repository.removeItem(itemId: custom.id)
        #expect(removed.items.contains { $0.id == custom.id } == false)

        await #expect(throws: CorbieError.self) {
            _ = try await repository.addItem(setId: set.id, draft: ChoreItemDraft(title: "   "))
        }
        await #expect(throws: CorbieError.self) {
            _ = try await repository.startRating(setId: set.id)
        }
    }

    @Test func yourRatingsStayYoursUntilBothOfYouAreDone() async throws {
        let (world, repository) = try await world()
        let now = DomainClock.date("2026-09-07 10:00", in: calendar)
        let set = try await repository.startSet(spaceId: world.space.id, catalogIds: [], memberId: world.me.id, at: now)
        let mine = try await rateEverything(
            repository,
            set: set,
            memberId: world.me.id,
            verdict: { _ in .hate },
            at: now
        )
        #expect(mine.hasRatedEverything(world.me.id))
        #expect(mine.status == .rating)

        let seenByPartner = try #require(
            try await repository.activeSet(spaceId: world.space.id, viewerMemberId: world.partner.id)
        )
        #expect(seenByPartner.items.allSatisfy { $0.ratings.isEmpty })
        #expect(seenByPartner.hasRatedEverything(world.me.id))
        #expect(seenByPartner.ratedItemCount(by: world.partner.id) == 0)

        let firstItem = try #require(set.includedItems.first)
        _ = try await repository.rate(itemId: firstItem.id, memberId: world.partner.id, verdict: .like, at: now)
        let halfway = try #require(
            try await repository.activeSet(spaceId: world.space.id, viewerMemberId: world.partner.id)
        )
        #expect(halfway.items.first { $0.id == firstItem.id }?.ratings.map(\.memberId) == [world.partner.id])

        _ = try await rateEverything(
            repository,
            set: set,
            memberId: world.partner.id,
            verdict: { _ in .like },
            at: now
        )
        let open = try #require(try await repository.activeSet(spaceId: world.space.id, viewerMemberId: world.me.id))
        #expect(open.items.allSatisfy { $0.ratings.count == 2 })
    }

    @Test func theLastCardCanBeTakenBack() async throws {
        let (world, repository) = try await world()
        let now = DomainClock.date("2026-09-07 10:00", in: calendar)
        let set = try await repository.startSet(spaceId: world.space.id, catalogIds: [], memberId: world.me.id, at: now)
        let item = try #require(set.includedItems.first)
        _ = try await repository.rate(itemId: item.id, memberId: world.me.id, verdict: .hate, at: now)
        let changed = try await repository.rate(itemId: item.id, memberId: world.me.id, verdict: .like, at: now)
        #expect(changed.items.first { $0.id == item.id }?.verdict(of: world.me.id) == .like)
        let undone = try await repository.undoRating(itemId: item.id, memberId: world.me.id)
        #expect(undone.items.first { $0.id == item.id }?.verdict(of: world.me.id) == nil)
    }

    @Test func aRevealNeedsEveryCardFromBothOfYou() async throws {
        let (world, repository) = try await world()
        let now = DomainClock.date("2026-09-07 10:00", in: calendar)
        let set = try await repository.startSet(spaceId: world.space.id, catalogIds: [], memberId: world.me.id, at: now)
        _ = try await rateEverything(repository, set: set, memberId: world.me.id, verdict: { _ in .fine }, at: now)
        await #expect(throws: CorbieError.self) {
            _ = try await repository.reveal(setId: set.id, at: now)
        }
        await #expect(throws: CorbieError.self) {
            _ = try await repository.apply(setId: set.id, memberId: world.me.id, at: now)
        }
    }

    @Test func aRevealedSetCarriesAnAssignmentForEveryChore() async throws {
        let (world, repository) = try await world()
        let set = try await revealed(world, repository)
        #expect(set.status == .revealed)
        #expect(set.revealedAt != nil)
        for item in set.includedItems {
            let assignment = try #require(item.assignment)
            #expect(assignment.memberAId != nil)
            #expect(assignment.memberBId != nil)
            if assignment.result == .member {
                #expect(assignment.assignedMemberId != nil)
            } else {
                #expect(assignment.assignedMemberId == nil)
            }
        }
        await #expect(throws: CorbieError.self) {
            _ = try await repository.rate(
                itemId: set.includedItems[0].id,
                memberId: world.me.id,
                verdict: .like,
                at: DomainClock.date("2026-09-08 10:00", in: calendar)
            )
        }
    }

    @Test func applyingTwiceKeepsOneTaskPerChore() async throws {
        let (world, repository) = try await world()
        let set = try await revealed(world, repository)
        let now = DomainClock.date("2026-09-07 11:00", in: calendar)
        let first = try await repository.apply(setId: set.id, memberId: world.me.id, at: now)
        #expect(first.count == set.includedItems.count)
        #expect(first.allSatisfy { $0.comesFromChoreSplit })
        #expect(first.allSatisfy { $0.recurrence != .none })

        let second = try await repository.apply(setId: set.id, memberId: world.me.id, at: now)
        #expect(Set(second.map(\.id)) == Set(first.map(\.id)))
        #expect(try world.count(TaskItem.entityName) == first.count)

        let applied = try #require(try await repository.set(id: set.id, viewerMemberId: world.me.id))
        #expect(applied.status == .applied)
        #expect(applied.appliedAt != nil)
        #expect(try await repository.activeSet(spaceId: world.space.id, viewerMemberId: world.me.id) == nil)
    }

    @Test func aChoreBothOfYouHateBecomesATaskThatChangesHands() async throws {
        let (world, repository) = try await world()
        let now = DomainClock.date("2026-09-07 10:00", in: calendar)
        let set = try await repository.startSet(spaceId: world.space.id, catalogIds: [], memberId: world.me.id, at: now)
        _ = try await rateEverything(repository, set: set, memberId: world.me.id, verdict: { _ in .hate }, at: now)
        _ = try await rateEverything(repository, set: set, memberId: world.partner.id, verdict: { _ in .hate }, at: now)
        _ = try await repository.reveal(setId: set.id, at: now)
        let tasks = try await repository.apply(setId: set.id, memberId: world.me.id, at: now)
        #expect(tasks.allSatisfy { $0.rotatesBetweenMembers })
        #expect(tasks.allSatisfy { $0.assigneeMemberId == nil })
    }

    @Test func aSecondSplitUpdatesTheTasksTheFirstOneMade() async throws {
        let (world, repository) = try await world()
        let set = try await revealed(world, repository)
        let firstRun = DomainClock.date("2026-09-07 11:00", in: calendar)
        let firstTasks = try await repository.apply(setId: set.id, memberId: world.me.id, at: firstRun)

        let later = DomainClock.date("2027-04-07 11:00", in: calendar)
        let resplit = try await repository.startSet(
            spaceId: world.space.id,
            catalogIds: Array(ChoreCatalog.bundled.preselectedIds.prefix(10)),
            memberId: world.partner.id,
            at: later
        )
        #expect(resplit.id != set.id)
        _ = try await rateEverything(repository, set: resplit, memberId: world.me.id, verdict: { _ in .fine }, at: later)
        _ = try await rateEverything(
            repository,
            set: resplit,
            memberId: world.partner.id,
            verdict: { _ in .neutral },
            at: later
        )
        _ = try await repository.reveal(setId: resplit.id, at: later)
        let secondTasks = try await repository.apply(setId: resplit.id, memberId: world.partner.id, at: later)
        #expect(secondTasks.count == 10)
        #expect(Set(secondTasks.map(\.id)).isSubset(of: Set(firstTasks.map(\.id))))
        #expect(try world.count(TaskItem.entityName) == firstTasks.count)

        let history = try await repository.history(spaceId: world.space.id, viewerMemberId: world.me.id)
        #expect(history.map(\.id) == [resplit.id, set.id])
        #expect(history.first?.needsResplit(at: later) == false)
        #expect(history.last?.needsResplit(at: later) == true)
    }
}
