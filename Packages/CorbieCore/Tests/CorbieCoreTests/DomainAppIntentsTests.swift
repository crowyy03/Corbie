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

    @Test func togglingAShoppingItemFlipsItBothWays() async throws {
        let world = try await makeWorld()
        let items = try await world.seed.controller.repositories.tasks.tasks(
            TaskQuery(spaceId: world.seed.space.id, folder: .folder(world.seed.shoppingFolder.id))
        )
        let first = try #require(items.first)
        let checked = try await TaskIntentRunner.toggleShoppingItem(
            taskId: first.id,
            persistence: world.persistence,
            now: world.now
        )
        #expect(checked.isDone)
        #expect(checked.doneByMemberId == world.seed.me.id)
        let unchecked = try await TaskIntentRunner.toggleShoppingItem(
            taskId: first.id,
            persistence: world.persistence,
            now: world.now
        )
        #expect(unchecked.isDone == false)
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

#if canImport(AppIntents)
import AppIntents

@Suite(.serialized) struct DomainAppIntentPerformTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "Europe/Berlin")

    @Test func everyIntentCarriesItsIdentifier() {
        let taskId = UUID()
        let itemId = UUID()
        #expect(ToggleTaskDoneIntent(taskID: taskId).taskID == taskId.uuidString)
        #expect(TakeTaskIntent(taskID: taskId).taskID == taskId.uuidString)
        #expect(ToggleShoppingItemIntent(taskID: itemId).taskID == itemId.uuidString)
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
}
#endif
