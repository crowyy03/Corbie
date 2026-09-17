import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct PersistentHistoryTests {
    @Test func aWriteFromAnotherProcessIsMergedAndAdvancesTheToken() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "corbie-history-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let app = CoreDataStack(storesIn: directory, author: .app)
        let widgets = CoreDataStack(storesIn: directory, author: .widgets)
        #expect(app.loadFailure == nil)
        #expect(widgets.loadFailure == nil)
        let observer = PersistentHistoryObserver(container: app.container, author: .app, defaults: defaults)
        #expect(observer.storedToken == nil)

        let counter = ReloadCounter()
        let token = NotificationCenter.default.addObserver(
            forName: WidgetReloadRequest.notificationName,
            object: nil,
            queue: nil
        ) { _ in counter.increment() }
        defer { NotificationCenter.default.removeObserver(token) }

        try write(into: widgets)
        #expect(try observer.process() >= 1)
        #expect(observer.storedToken != nil)
        #expect(counter.count >= 1)
        #expect(try observer.process() == 0)
    }

    @Test func historyIsDeletedOnlyUpToTheCutoffTheObserverIsGiven() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "corbie-history-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let stack = CoreDataStack(storesIn: directory, author: .app)
        let widgets = CoreDataStack(storesIn: directory, author: .widgets)
        try write(into: widgets)
        #expect(try transactionCount(in: stack) >= 1)

        let keeping = PersistentHistoryObserver(container: stack.container, author: .share, defaults: defaults)
        #expect(try keeping.process() >= 1)
        #expect(try transactionCount(in: stack) >= 1)

        let neverUploaded = PersistentHistoryObserver(
            container: stack.container,
            author: .tests,
            defaults: defaults,
            cleanupCutoff: { ids in
                HistoryCleanupRule.cutoff(now: Date(), storeIdentifiers: ids, lastUploadStarts: [:], retention: 0)
            }
        )
        #expect(try neverUploaded.process() >= 1)
        #expect(try transactionCount(in: stack) >= 1)

        let seenIdentifiers = IdentifierBox()
        let uploaded = PersistentHistoryObserver(
            container: stack.container,
            author: .app,
            defaults: defaults,
            cleanupCutoff: { ids in
                seenIdentifiers.identifiers = ids
                let starts = Dictionary(uniqueKeysWithValues: ids.map { ($0, Date()) })
                return HistoryCleanupRule.cutoff(now: Date(), storeIdentifiers: ids, lastUploadStarts: starts, retention: 0)
            }
        )
        #expect(try uploaded.process() >= 1)
        #expect(try transactionCount(in: stack) == 0)
        #expect(seenIdentifiers.identifiers.count == stack.container.persistentStoreCoordinator.persistentStores.count)
    }

    @Test func theTokenKeyIsScopedToTheProcess() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let stack = CoreDataStack(storesIn: directory)
        let app = PersistentHistoryObserver(container: stack.container, author: .app)
        let share = PersistentHistoryObserver(container: stack.container, author: .share)
        #expect(app.tokenKey == "history.token.app")
        #expect(share.tokenKey == "history.token.share")
    }

    @Test func recordsMergedBeforeAHandlerExistsReachItOnceItIsSet() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "corbie-history-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let app = CoreDataStack(storesIn: directory, author: .app)
        let widgets = CoreDataStack(storesIn: directory, author: .widgets)
        let holding = PersistentHistoryObserver(
            container: app.container,
            author: .app,
            defaults: defaults,
            holdsRecordsUntilHandled: true
        )
        let dropping = PersistentHistoryObserver(container: app.container, author: .share, defaults: defaults)
        try write(into: widgets)
        #expect(try holding.process() >= 1)
        #expect(try dropping.process() >= 1)

        let held = RecordBox()
        holding.setHandler { held.append($0) }
        #expect(held.records.map(\.entityName) == [Space.entityName])
        #expect(held.records.first?.author == TransactionAuthor.widgets.rawValue)
        holding.setHandler { held.append($0) }
        #expect(held.records.count == 1)

        let dropped = RecordBox()
        dropping.setHandler { dropped.append($0) }
        #expect(dropped.records.isEmpty)
    }

    private func makeDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-history-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func transactionCount(in stack: CoreDataStack) throws -> Int {
        let context = stack.newBackgroundContext()
        return try context.performAndWait {
            let result = try context.execute(NSPersistentHistoryChangeRequest.fetchHistory(after: nil as NSPersistentHistoryToken?))
            return ((result as? NSPersistentHistoryResult)?.result as? [NSPersistentHistoryTransaction])?.count ?? 0
        }
    }

    private func write(into stack: CoreDataStack) throws {
        let context = stack.newBackgroundContext()
        try context.performAndWait {
            let space = Space(context: context)
            if let store = stack.store(for: .privateStore) {
                context.assign(space, to: store)
            }
            space.displayCurrency = "USD"
            try context.save()
        }
    }
}

private final class RecordBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [RemoteChangeRecord] = []

    var records: [RemoteChangeRecord] {
        lock.withLock { stored }
    }

    func append(_ records: [RemoteChangeRecord]) {
        lock.withLock { stored.append(contentsOf: records) }
    }
}

private final class IdentifierBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [String] = []

    var identifiers: [String] {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}
