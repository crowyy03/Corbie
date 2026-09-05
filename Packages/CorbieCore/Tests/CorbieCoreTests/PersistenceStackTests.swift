import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct PersistenceStackTests {
    @Test func inMemoryStackLoadsWithoutCloudKit() {
        let stack = CoreDataStack(inMemoryAuthor: .tests)
        #expect(stack.loadFailure == nil)
        #expect(stack.isCloudKitEnabled == false)
        #expect(stack.cloudKitContainer == nil)
        #expect(stack.container.persistentStoreCoordinator.persistentStores.count == 1)
        #expect(stack.store(for: .privateStore) != nil)
    }

    @Test func contextsCarryTheProcessAuthorAndMergePolicy() {
        let stack = CoreDataStack(inMemoryAuthor: .widgets)
        #expect(stack.viewContext.transactionAuthor == "widgets")
        #expect(stack.viewContext.automaticallyMergesChangesFromParent)
        let background = stack.newBackgroundContext()
        #expect(background.transactionAuthor == "widgets")
        #expect((background.mergePolicy as AnyObject) === NSMergePolicy.mergeByPropertyObjectTrump)
    }

    @Test func storesDirectoryExistsBeforeStoresAreOpened() {
        let directory = CoreDataStack.storesDirectory()
        #expect(FileManager.default.fileExists(atPath: directory.path))
    }

    @Test func storeFileNamesMatchTheTwoScopes() {
        #expect(StoreScope.privateStore.fileName == "private.sqlite")
        #expect(StoreScope.sharedStore.fileName == "shared.sqlite")
    }

    @Test func previewControllerIsUsableAndIsolatedPerCall() async throws {
        let first = PersistenceController.inMemory()
        let second = PersistenceController.inMemory()
        let space = try await first.repositories.spaces.create()
        #expect(try await second.repositories.spaces.space(id: space.id) == nil)
        #expect(PersistenceController.preview.stack.isCloudKitEnabled == false)
    }

    @Test func schemaInitialisationIsSkippedWithoutTheFlag() throws {
        let stack = CoreDataStack(inMemoryAuthor: .tests)
        try stack.initializeCloudKitSchemaIfRequested()
    }
}
