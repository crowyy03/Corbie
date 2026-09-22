import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct StoreChangesTests {
    @Test func aRepositoryWritePostsTheEntitiesItSaved() async throws {
        let controller = PersistenceController.inMemory()
        let changes = controller.repositories.changes.stream()
        var iterator = changes.makeAsyncIterator()

        let space = try await controller.repositories.spaces.create(displayCurrency: "USD", creatorMemberId: nil, now: Date())
        _ = try await controller.repositories.wishes.create(WishDraft(spaceId: space.id, ownerMemberId: UUID(), title: "Lamp"))

        let first = try #require(await iterator.next())
        #expect(first.origin == .thisProcess)
        #expect(first.entityNames.isEmpty == false)
        var latest = first
        while latest.entityNames.contains(Wish.entityName) == false {
            latest = try #require(await iterator.next())
        }
        #expect(latest.entityNames.contains(Wish.entityName))
    }

    @Test func aWriteThatSavesNothingPostsNothing() async throws {
        let controller = PersistenceController.inMemory()
        let space = try await controller.repositories.spaces.create(displayCurrency: "USD", creatorMemberId: nil, now: Date())
        let recorder = ChangeRecorder(controller.repositories.changes)

        _ = try await controller.repositories.wishes.wishes(WishQuery(spaceId: space.id, owner: .any, fulfilled: nil))
        try await controller.repositories.wishes.delete(id: UUID())

        try await Task.sleep(for: .milliseconds(200))
        #expect(recorder.changes.isEmpty)
    }

    @Test func aWriteFromAnotherWriterReachesTheFeedAsComingFromElsewhere() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "corbie-changes-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let app = PersistenceController(stack: CoreDataStack(storesIn: directory, author: .app, historyDefaults: defaults))
        let space = try await app.repositories.spaces.create(displayCurrency: "USD", creatorMemberId: nil, now: Date())
        let importer = PersistenceController(stack: CoreDataStack(storesIn: directory, author: .widgets))
        let recorder = ChangeRecorder(app.repositories.changes)

        _ = try await importer.repositories.wishes.create(WishDraft(spaceId: space.id, ownerMemberId: UUID(), title: "Lamp"))
        _ = try app.stack.processHistory()

        try await recorder.wait { $0.contains { $0.origin == .elsewhere && $0.entityNames.contains(Wish.entityName) } }
    }

    @MainActor
    @Test func aSubscriptionReloadsOnTheMainActorAndStopsWhenReleased() async throws {
        let controller = PersistenceController.inMemory()
        let feed = controller.repositories.changes
        let counter = MainActorCounter()
        var subscription: StoreChangeSubscription? = feed.subscribe {
            MainActor.assertIsolated()
            counter.value += 1
        }
        #expect(feed.listenerCount == 1)

        await Task.detached {
            feed.post(StoreChange(origin: .elsewhere, entityNames: [Wish.entityName]))
        }.value
        let deadline = Date().addingTimeInterval(5)
        while counter.value == 0, Date() < deadline {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(counter.value == 1)

        subscription?.cancel()
        subscription = nil
        let released = Date().addingTimeInterval(5)
        while feed.listenerCount > 0, Date() < released {
            try await Task.sleep(for: .milliseconds(20))
        }
        #expect(feed.listenerCount == 0)
        #expect(subscription == nil)
    }

    private func makeDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-changes-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

@MainActor
private final class MainActorCounter {
    var value = 0
}

private final class ChangeRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [StoreChange] = []
    private var task: Task<Void, Never>?

    init(_ feed: StoreChanges) {
        let stream = feed.stream()
        task = Task { [weak self] in
            for await change in stream {
                self?.append(change)
            }
        }
    }

    deinit {
        task?.cancel()
    }

    var changes: [StoreChange] {
        lock.withLock { recorded }
    }

    func wait(timeout: TimeInterval = 5, until condition: ([StoreChange]) -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition(changes) { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        Issue.record("the feed never delivered the expected change, got \(changes)")
    }

    private func append(_ change: StoreChange) {
        lock.withLock { recorded.append(change) }
    }
}
