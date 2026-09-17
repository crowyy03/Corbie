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

    @Test func onlyAnObserverWithARetentionPurgesHistory() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "corbie-history-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let stack = CoreDataStack(storesIn: directory, author: .app)
        let widgets = CoreDataStack(storesIn: directory, author: .widgets)
        try write(into: widgets)
        #expect(try transactionCount(in: stack) >= 1)

        let keeping = PersistentHistoryObserver(container: stack.container, author: .share, defaults: defaults, retention: nil)
        #expect(try keeping.process() >= 1)
        #expect(try transactionCount(in: stack) >= 1)

        let purging = PersistentHistoryObserver(container: stack.container, author: .app, defaults: defaults, retention: 0)
        #expect(try purging.process() >= 1)
        #expect(try transactionCount(in: stack) == 0)
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
