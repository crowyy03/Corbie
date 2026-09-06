import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct StoreResetTests {
    @Test func wipingRemovesEveryRowAndLeavesAWorkingStore() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "corbie-reset-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(Data([1, 2, 3]), forKey: StoreReset.historyTokenKey(author: .app))

        let stack = CoreDataStack(storesIn: directory, author: .app)
        #expect(stack.loadFailure == nil)
        try seed(into: stack)
        #expect(try count(in: stack) == 1)

        try StoreReset(stack: stack, defaults: defaults).wipe()

        #expect(try count(in: stack) == 0)
        #expect(defaults.data(forKey: StoreReset.historyTokenKey(author: .app)) == nil)
        #expect(stack.container.persistentStoreCoordinator.persistentStores.count == 2)
        try seed(into: stack)
        #expect(try count(in: stack) == 1)
    }

    @Test func wipingDeletesTheStoreFilesFromDisk() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "corbie-reset-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let stack = CoreDataStack(storesIn: directory, author: .app)
        try seed(into: stack)
        let file = directory.appendingPathComponent(StoreScope.privateStore.fileName)
        let before = try #require(try? Data(contentsOf: file))
        #expect(before.isEmpty == false)

        try StoreReset(stack: stack, defaults: defaults).wipe()

        let after = try #require(try? Data(contentsOf: file))
        #expect(after.count <= before.count)
        #expect(try count(in: stack) == 0)
    }

    @Test func removingFilesTakesTheWalAndShmSidecarsWithIt() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = directory.appendingPathComponent("private.sqlite")
        let wal = directory.appendingPathComponent("private.sqlite-wal")
        try Data([0]).write(to: store)
        try Data([0]).write(to: wal)

        let removed = StoreReset.removeFiles(at: [store])

        #expect(removed.count == 2)
        #expect(FileManager.default.fileExists(atPath: store.path) == false)
        #expect(FileManager.default.fileExists(atPath: wal.path) == false)
    }

    @Test func wipingAnInMemoryStackLeavesItUsable() throws {
        let suiteName = "corbie-reset-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let stack = CoreDataStack(inMemoryAuthor: .tests)
        try seed(into: stack)

        try StoreReset(stack: stack, defaults: defaults).wipe()

        #expect(try count(in: stack) == 0)
        try seed(into: stack)
        #expect(try count(in: stack) == 1)
    }

    private func makeDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-reset-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func seed(into stack: CoreDataStack) throws {
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

    private func count(in stack: CoreDataStack) throws -> Int {
        let context = stack.viewContext
        return try context.performAndWait {
            try context.count(for: NSFetchRequest<NSFetchRequestResult>(entityName: Space.entityName))
        }
    }
}
