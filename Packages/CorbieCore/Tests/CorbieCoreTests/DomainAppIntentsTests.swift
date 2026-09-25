import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainAppIntentsTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "Europe/Berlin")

    private struct World {
        let persistence: IntentPersistence
        let seed: PreviewSeedResult
        let now: Date
    }

    private func makeWorld(signedInAs appleUserId: String = "preview.me") async throws -> World {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let seed = try await PreviewSeed.make(now: now, calendar: calendar)
        let secrets = InMemorySecretStore()
        let identity = MemberIdentity(store: secrets)
        try identity.setAppleUserID(appleUserId)
        let persistence = IntentPersistence()
        persistence.use(controller: seed.controller, identity: identity)
        return World(persistence: persistence, seed: seed, now: now)
    }

    @Test func theInjectedControllerAndIdentityAreUsed() async throws {
        let world = try await makeWorld()
        #expect(try await world.persistence.currentMemberId() == world.seed.me.id)
    }

    @Test func markingATaskDoneStoresTheCompletion() async throws {
        let world = try await makeWorld()
        let task = try #require(world.seed.tasks.first { $0.title == "Book the vet" })
        let completion = try await TaskIntentRunner.markDone(
            taskId: task.id,
            persistence: world.persistence,
            calendar: calendar,
            now: world.now
        )
        #expect(completion.task.isDone)
        #expect(completion.task.doneByMemberId == world.seed.me.id)
        #expect(completion.nextOccurrenceDueAt == nil)
        let stored = try await world.seed.controller.repositories.tasks.task(id: task.id)
        #expect(stored?.isDone == true)
        #expect(stored?.doneAt == world.now)
    }

    @Test func completingATaskDropsItsDueTodayAlert() async throws {
        let world = try await makeWorld()
        let center = FakeNotificationCenter()
        let task = try #require(world.seed.tasks.first { $0.title == "Book the vet" })
        _ = try await TaskIntentRunner.markDone(
            taskId: task.id,
            persistence: world.persistence,
            notifications: center,
            calendar: calendar,
            now: world.now
        )
        let removed = await center.removedIdentifiers
        #expect(removed == [NotificationIdentifier.taskDueToday(taskId: task.id)])
    }

    @Test func aTaskThatWasAlreadyDoneLeavesNotificationsAlone() async throws {
        let world = try await makeWorld()
        let center = FakeNotificationCenter()
        let task = try #require(world.seed.tasks.first { $0.title == "Call the landlord" })
        _ = try await TaskIntentRunner.markDone(
            taskId: task.id,
            persistence: world.persistence,
            notifications: center,
            calendar: calendar,
            now: world.now
        )
        let removed = await center.removedIdentifiers
        #expect(removed.isEmpty)
    }

    @Test func aRecurringTaskGetsItsNextOccurrence() async throws {
        let world = try await makeWorld()
        let task = try #require(world.seed.tasks.first { $0.title == "Water the plants" })
        let completion = try await TaskIntentRunner.markDone(
            taskId: task.id,
            persistence: world.persistence,
            calendar: calendar,
            now: world.now
        )
        let expected = RecurrenceEngine.nextOccurrence(for: task, completedAt: world.now, calendar: calendar)
        #expect(completion.nextOccurrenceDueAt == expected)
        let open = try await world.seed.controller.repositories.tasks.tasks(
            TaskQuery(spaceId: world.seed.space.id)
        )
        let clones = open.filter { $0.title == "Water the plants" }
        #expect(clones.count == 1)
        #expect(clones[0].id != task.id)
        #expect(clones[0].dueAt == expected)
        #expect(clones[0].recurrence == task.recurrence)
    }

    @Test func markingAnAlreadyDoneTaskChangesNothing() async throws {
        let world = try await makeWorld()
        let task = try #require(world.seed.tasks.first { $0.isDone })
        let completion = try await TaskIntentRunner.markDone(
            taskId: task.id,
            persistence: world.persistence,
            calendar: calendar,
            now: world.now
        )
        #expect(completion.task.doneAt == task.doneAt)
        #expect(completion.nextOccurrenceDueAt == nil)
    }

    @Test func markingAMissingTaskFails() async throws {
        let world = try await makeWorld()
        await #expect(throws: CorbieError.self) {
            _ = try await TaskIntentRunner.markDone(
                taskId: UUID(),
                persistence: world.persistence,
                calendar: calendar,
                now: world.now
            )
        }
    }

    @Test func takingAFreeTaskAssignsItToTheSignedInMember() async throws {
        let world = try await makeWorld(signedInAs: "preview.partner")
        let task = try #require(world.seed.tasks.first { $0.title == "Buy milk" })
        let taken = try await TaskIntentRunner.take(
            taskId: task.id,
            persistence: world.persistence,
            now: world.now
        )
        #expect(taken.assigneeMemberId == world.seed.partner.id)
        #expect(taken.takenAt == world.now)
    }

    @Test func takingWithoutASignedInMemberFails() async throws {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let seed = try await PreviewSeed.make(now: now, calendar: calendar)
        let persistence = IntentPersistence()
        persistence.use(controller: seed.controller, identity: MemberIdentity(store: InMemorySecretStore()))
        let task = try #require(seed.tasks.first { $0.title == "Buy milk" })
        await #expect(throws: CorbieError.self) {
            _ = try await TaskIntentRunner.take(taskId: task.id, persistence: persistence, now: now)
        }
    }

    @Test func tappingAShoppingRowSetsTheOppositeOfWhatItShowed() async throws {
        let world = try await makeWorld()
        let items = try await world.seed.controller.repositories.lists.items(listId: world.seed.shoppingList.id)
        let first = try #require(items.first { $0.isChecked == false })
        let checked = try await TaskIntentRunner.toggleShoppingItem(
            itemId: first.id,
            showedChecked: false,
            persistence: world.persistence,
            now: world.now
        )
        #expect(checked.isChecked)
        #expect(checked.checkedByMemberId == world.seed.me.id)
        let unchecked = try await TaskIntentRunner.toggleShoppingItem(
            itemId: first.id,
            showedChecked: true,
            persistence: world.persistence,
            now: world.now
        )
        #expect(unchecked.isChecked == false)
        #expect(unchecked.checkedByMemberId == nil)
    }

    @Test func aStaleUncheckedRowTappedAfterThePartnerTickedItLeavesTheTick() async throws {
        let world = try await makeWorld()
        let controller = world.seed.controller
        let items = try await controller.repositories.lists.items(listId: world.seed.shoppingList.id)
        let stale = try #require(items.first { $0.isChecked == false })
        let partnerId = world.seed.partner.id
        let partnerTickedAt = world.now.addingTimeInterval(-600)
        try await OtherContext.change(ListItem.entityName, id: stale.id, in: controller) { (item: ListItem) in
            item.isChecked = true
            item.checkedByMemberId = partnerId
            item.checkedAt = partnerTickedAt
        }

        let tapped = try await TaskIntentRunner.toggleShoppingItem(
            itemId: stale.id,
            showedChecked: stale.isChecked,
            persistence: world.persistence,
            now: world.now
        )

        #expect(tapped.isChecked)
        #expect(tapped.checkedByMemberId == partnerId)
        #expect(tapped.checkedAt == partnerTickedAt)
        let stored = try await controller.repositories.lists.items(listId: world.seed.shoppingList.id)
        let item = try #require(stored.first { $0.id == stale.id })
        #expect(item.isChecked)
        #expect(item.checkedByMemberId == partnerId)
    }

    @Test func aRowThatShowedCheckedUnticksIt() async throws {
        let world = try await makeWorld()
        let controller = world.seed.controller
        let items = try await controller.repositories.lists.items(listId: world.seed.shoppingList.id)
        let open = try #require(items.first { $0.isChecked == false })
        let partnerId = world.seed.partner.id
        let ticked = try await controller.repositories.lists.setItemChecked(
            itemId: open.id,
            true,
            memberId: partnerId,
            at: world.now
        )

        let tapped = try await TaskIntentRunner.toggleShoppingItem(
            itemId: ticked.id,
            showedChecked: ticked.isChecked,
            persistence: world.persistence,
            now: world.now
        )

        #expect(tapped.isChecked == false)
        #expect(tapped.checkedByMemberId == nil)
        #expect(tapped.checkedAt == nil)
    }

    @Test func aStaleCheckedRowTappedAfterThePartnerUntickedItStaysUnticked() async throws {
        let world = try await makeWorld()
        let controller = world.seed.controller
        let items = try await controller.repositories.lists.items(listId: world.seed.shoppingList.id)
        let open = try #require(items.first { $0.isChecked == false })
        let stale = try await controller.repositories.lists.setItemChecked(
            itemId: open.id,
            true,
            memberId: world.seed.me.id,
            at: world.now
        )
        try await OtherContext.change(ListItem.entityName, id: stale.id, in: controller) { (item: ListItem) in
            item.isChecked = false
            item.checkedByMemberId = nil
            item.checkedAt = nil
        }

        let tapped = try await TaskIntentRunner.toggleShoppingItem(
            itemId: stale.id,
            showedChecked: stale.isChecked,
            persistence: world.persistence,
            now: world.now
        )

        #expect(tapped.isChecked == false)
        #expect(tapped.checkedByMemberId == nil)
    }

    @Test func aSpaceWithAPaidMirrorMayWrite() async throws {
        let world = try await makeWorld()
        world.persistence.use(monetization: MonetizationTestSupport.enabled)
        #expect(await TaskIntentRunner.isReadOnly(persistence: world.persistence, now: world.now) == false)
    }

    @Test func aSpaceWhoseSubscriptionEndedIsReadOnlyWhileMonetizationIsOn() async throws {
        let world = try await makeWorld()
        try await IntentAccessTestSupport.endSubscription(of: world.seed)
        world.persistence.use(monetization: MonetizationTestSupport.enabled)
        #expect(await TaskIntentRunner.isReadOnly(persistence: world.persistence, now: world.now))
    }

    @Test func monetizationOffNeverMakesTheSpaceReadOnly() async throws {
        let world = try await makeWorld()
        try await IntentAccessTestSupport.endSubscription(of: world.seed)
        world.persistence.use(monetization: IntentAccessTestSupport.monetizationOff)
        #expect(await TaskIntentRunner.isReadOnly(persistence: world.persistence, now: world.now) == false)
    }

    @Test func identifiersMustBeUUIDs() throws {
        let id = UUID()
        #expect(try TaskIntentRunner.identifier(id.uuidString) == id)
        #expect(throws: CorbieError.self) {
            _ = try TaskIntentRunner.identifier("not-a-uuid")
        }
    }

    @Test func theReloaderForwardsEveryWidgetReloadRequest() async throws {
        let center = NotificationCenter()
        let counter = ReloadCounter()
        let reloader = WidgetReloader()
        reloader.start(center: center) { counter.increment() }
        center.post(name: WidgetReloadRequest.notificationName, object: nil)
        center.post(name: WidgetReloadRequest.notificationName, object: nil)
        #expect(counter.count == 2)
        reloader.stop(center: center)
        center.post(name: WidgetReloadRequest.notificationName, object: nil)
        #expect(counter.count == 2)
    }
}

enum IntentAccessTestSupport {
    static let monetizationOff: MonetizationFlagStore = {
        let store = MonetizationFlagStore(suiteName: "corbie.tests.monetization.disabled")
        store.record(false)
        return store
    }()

    static func endSubscription(of seed: PreviewSeedResult) async throws {
        _ = try await seed.controller.repositories.spaces.setSubscription(
            spaceId: seed.space.id,
            status: .expired,
            expiresAt: nil,
            payerMemberId: nil
        )
    }
}

#if canImport(AppIntents)
import AppIntents

@Suite(.serialized) struct DomainAppIntentPerformTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "Europe/Berlin")

    @Test func everyIntentCarriesItsIdentifier() {
        let taskId = UUID()
        let itemId = UUID()
        #expect(ToggleTaskDoneIntent(taskID: taskId).taskID == taskId.uuidString)
        #expect(TakeTaskIntent(taskID: taskId).taskID == taskId.uuidString)
        let shoppingIntent = ToggleShoppingItemIntent(itemID: itemId, showedChecked: true)
        #expect(shoppingIntent.itemID == itemId.uuidString)
        #expect(shoppingIntent.showedChecked)
    }

    @Test func performingTheToggleIntentWritesThroughTheSharedPersistence() async throws {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let seed = try await PreviewSeed.make(now: now, calendar: calendar)
        let identity = MemberIdentity(store: InMemorySecretStore())
        try identity.setAppleUserID("preview.me")
        IntentPersistence.shared.use(controller: seed.controller, identity: identity)
        defer { IntentPersistence.shared.reset() }
        let task = try #require(seed.tasks.first { $0.title == "Book the vet" })
        _ = try await ToggleTaskDoneIntent(taskID: task.id).perform()
        let stored = try await seed.controller.repositories.tasks.task(id: task.id)
        #expect(stored?.isDone == true)
        #expect(stored?.doneByMemberId == seed.me.id)
    }

    @Test func performingTheShoppingIntentKeepsATickThatIsAlreadyThere() async throws {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let seed = try await PreviewSeed.make(now: now, calendar: calendar)
        let identity = MemberIdentity(store: InMemorySecretStore())
        try identity.setAppleUserID("preview.me")
        IntentPersistence.shared.use(controller: seed.controller, identity: identity)
        defer { IntentPersistence.shared.reset() }
        let lists = seed.controller.repositories.lists
        let open = try #require(try await lists.items(listId: seed.shoppingList.id).first { $0.isChecked == false })
        _ = try await lists.setItemChecked(itemId: open.id, true, memberId: seed.partner.id, at: now)

        _ = try await ToggleShoppingItemIntent(itemID: open.id, showedChecked: false).perform()

        let stored = try #require(try await lists.items(listId: seed.shoppingList.id).first { $0.id == open.id })
        #expect(stored.isChecked)
        #expect(stored.checkedByMemberId == seed.partner.id)
    }

    @Test func noIntentWritesWhenTheSubscriptionHasEnded() async throws {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let seed = try await PreviewSeed.make(now: now, calendar: calendar)
        try await IntentAccessTestSupport.endSubscription(of: seed)
        let identity = MemberIdentity(store: InMemorySecretStore())
        try identity.setAppleUserID("preview.partner")
        IntentPersistence.shared.use(controller: seed.controller, identity: identity)
        IntentPersistence.shared.use(monetization: MonetizationTestSupport.enabled)
        defer { IntentPersistence.shared.reset() }
        let tasks = seed.controller.repositories.tasks
        let lists = seed.controller.repositories.lists
        let due = try #require(seed.tasks.first { $0.title == "Book the vet" })
        let free = try #require(seed.tasks.first { $0.title == "Buy milk" })
        let item = try #require(try await lists.items(listId: seed.shoppingList.id).first { $0.isChecked == false })

        await #expect(throws: (any Error).self) {
            _ = try await ToggleTaskDoneIntent(taskID: due.id).perform()
        }
        await #expect(throws: (any Error).self) {
            _ = try await TakeTaskIntent(taskID: free.id).perform()
        }
        await #expect(throws: (any Error).self) {
            _ = try await ToggleShoppingItemIntent(itemID: item.id, showedChecked: false).perform()
        }

        #expect(try await tasks.task(id: due.id)?.isDone == false)
        #expect(try await tasks.task(id: free.id)?.assigneeMemberId == free.assigneeMemberId)
        let stored = try #require(try await lists.items(listId: seed.shoppingList.id).first { $0.id == item.id })
        #expect(stored.isChecked == false)
    }

    @Test func aPaidSpaceStillTakesATaskFromTheWidget() async throws {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let seed = try await PreviewSeed.make(now: now, calendar: calendar)
        let identity = MemberIdentity(store: InMemorySecretStore())
        try identity.setAppleUserID("preview.partner")
        IntentPersistence.shared.use(controller: seed.controller, identity: identity)
        IntentPersistence.shared.use(monetization: MonetizationTestSupport.enabled)
        defer { IntentPersistence.shared.reset() }
        let free = try #require(seed.tasks.first { $0.title == "Buy milk" })

        _ = try await TakeTaskIntent(taskID: free.id).perform()

        #expect(try await seed.controller.repositories.tasks.task(id: free.id)?.assigneeMemberId == seed.partner.id)
    }
}
#endif
