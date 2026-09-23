import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct CloudKitSyncWaitTests {
    static let eventKey = "test.event"
    private let store = "shared-store"
    private let marker = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func aFinishedExportOfTheStoreEndsTheWait() async {
        let center = NotificationCenter()
        let wait = makeWait(center: center)
        let posting = Task {
            try? await Task.sleep(for: .milliseconds(20))
            post(event(.exporting, startedAt: marker.addingTimeInterval(1)), on: center)
        }
        #expect(await wait.outcome(within: .seconds(5)) == .finished)
        await posting.value
    }

    @Test func anExportThatFinishedBeforeTheWaitStillCounts() async {
        let center = NotificationCenter()
        let wait = makeWait(center: center)
        post(event(.exporting, startedAt: marker), on: center)
        #expect(await wait.outcome(within: .seconds(5)) == .finished)
    }

    @Test func aFailedExportIsReportedWithItsReason() async {
        let center = NotificationCenter()
        let wait = makeWait(center: center)
        post(event(.exporting, startedAt: marker.addingTimeInterval(1), succeeded: false, failure: "offline"), on: center)
        #expect(await wait.outcome(within: .seconds(5)) == .failed("offline"))
    }

    @Test func otherEventsDoNotEndTheWait() async {
        let center = NotificationCenter()
        let wait = makeWait(center: center)
        let later = marker.addingTimeInterval(1)
        post(event(.importing, startedAt: later), on: center)
        post(event(.setup, startedAt: later), on: center)
        post(event(.exporting, startedAt: later, endedAt: nil), on: center)
        post(event(.exporting, startedAt: marker.addingTimeInterval(-1)), on: center)
        post(event(.exporting, store: "private-store", startedAt: later), on: center)
        center.post(name: NSPersistentCloudKitContainer.eventChangedNotification, object: nil)
        #expect(await wait.outcome(within: .milliseconds(100)) == .timedOut)
    }

    @Test func theFirstOutcomeWins() async {
        let center = NotificationCenter()
        let wait = makeWait(center: center)
        #expect(await wait.outcome(within: .milliseconds(10)) == .timedOut)
        post(event(.exporting, startedAt: marker), on: center)
        #expect(await wait.outcome(within: .seconds(5)) == .timedOut)
    }

    @Test func anImportWaitIgnoresExportsAndAcceptsAnyStoreWhenNoneIsNamed() async {
        let center = NotificationCenter()
        let wait = makeWait(kind: .importing, store: nil, center: center)
        let later = marker.addingTimeInterval(1)
        post(event(.exporting, startedAt: later), on: center)
        post(event(.importing, startedAt: later, endedAt: nil), on: center)
        post(event(.importing, store: "private-store", startedAt: later), on: center)
        #expect(await wait.outcome(within: .seconds(5)) == .finished)
    }

    private func makeWait(
        kind: CloudKitMirroringEvent.Kind = .exporting,
        store: String? = "shared-store",
        center: NotificationCenter
    ) -> CloudKitSyncWait {
        CloudKitSyncWait(
            kind: kind,
            storeIdentifier: store,
            startedAtOrAfter: marker,
            center: center,
            readEvent: { notification in
                notification.userInfo?[CloudKitSyncWaitTests.eventKey] as? CloudKitMirroringEvent
            }
        )
    }

    private func event(
        _ kind: CloudKitMirroringEvent.Kind,
        store: String? = nil,
        startedAt: Date,
        endedAt: Date? = Date(timeIntervalSince1970: 1_800_000_100),
        succeeded: Bool = true,
        failure: String? = nil
    ) -> CloudKitMirroringEvent {
        CloudKitMirroringEvent(
            kind: kind,
            storeIdentifier: store ?? self.store,
            startedAt: startedAt,
            endedAt: endedAt,
            succeeded: succeeded,
            failure: failure
        )
    }

    private func post(_ event: CloudKitMirroringEvent, on center: NotificationCenter) {
        CloudKitEventPosting.post(event, on: center)
    }
}

@Suite struct CloudKitRunningImportsTests {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func anImportIsRunningFromItsStartUntilItsEnd() {
        let center = NotificationCenter()
        let imports = makeImports(center: center)
        let id = UUID()
        #expect(imports.earliestStart(storeIdentifier: nil) == nil)
        CloudKitEventPosting.post(importing(id, store: "shared", startedAt: start, endedAt: nil), on: center)
        #expect(imports.earliestStart(storeIdentifier: nil) == start)
        #expect(imports.earliestStart(storeIdentifier: "shared") == start)
        #expect(imports.earliestStart(storeIdentifier: "private") == nil)
        CloudKitEventPosting.post(importing(id, store: "shared", startedAt: start, endedAt: start + 3), on: center)
        #expect(imports.earliestStart(storeIdentifier: nil) == nil)
    }

    @Test func theEarliestOfSeveralRunningImportsIsReported() {
        let center = NotificationCenter()
        let imports = makeImports(center: center)
        CloudKitEventPosting.post(importing(UUID(), store: "shared", startedAt: start + 5, endedAt: nil), on: center)
        CloudKitEventPosting.post(importing(UUID(), store: "shared", startedAt: start, endedAt: nil), on: center)
        let export = CloudKitMirroringEvent(
            kind: .exporting,
            storeIdentifier: "shared",
            startedAt: start - 10,
            endedAt: nil,
            succeeded: false
        )
        CloudKitEventPosting.post(export, on: center)
        #expect(imports.earliestStart(storeIdentifier: "shared") == start)
    }

    private func makeImports(center: NotificationCenter) -> CloudKitRunningImports {
        CloudKitRunningImports(center: center) { notification in
            notification.userInfo?[CloudKitSyncWaitTests.eventKey] as? CloudKitMirroringEvent
        }
    }

    private func importing(_ id: UUID, store: String, startedAt: Date, endedAt: Date?) -> CloudKitMirroringEvent {
        CloudKitMirroringEvent(
            kind: .importing,
            storeIdentifier: store,
            startedAt: startedAt,
            endedAt: endedAt,
            succeeded: endedAt != nil,
            identifier: id
        )
    }
}

@Suite struct CloudKitImportWatchTests {
    @Test func aStackWithoutMirroringHasNoImportToWatch() async throws {
        let stack = CoreDataStack(inMemoryAuthor: .tests)
        let spaceId = try insertSpace(into: try #require(stack.store(for: .privateStore)), stack: stack)
        #expect(await stack.watchImport(intoStoreHolding: spaceId) == nil)
    }

    @Test func theWatchedStoreIsTheOneHoldingTheSpace() async throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-import-watch-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let stack = CoreDataStack(storesIn: directory)
        #expect(stack.loadFailure == nil)

        let owned = try insertSpace(into: try #require(stack.store(for: .privateStore)), stack: stack)
        let joined = try insertSpace(into: try #require(stack.store(for: .sharedStore)), stack: stack)

        #expect(await stack.scope(holdingSpace: owned) == .privateStore)
        #expect(await stack.scope(holdingSpace: joined) == .sharedStore)
        #expect(await stack.scope(holdingSpace: UUID()) == nil)
    }

    private func insertSpace(into store: NSPersistentStore, stack: CoreDataStack) throws -> UUID {
        let context = stack.newBackgroundContext()
        return try context.performAndWait {
            let space = Space(context: context)
            context.assign(space, to: store)
            space.createdAt = Date()
            try context.save()
            return try #require(space.id)
        }
    }
}

enum CloudKitEventPosting {
    static func post(_ event: CloudKitMirroringEvent, on center: NotificationCenter) {
        center.post(
            name: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            userInfo: [CloudKitSyncWaitTests.eventKey: event]
        )
    }
}
