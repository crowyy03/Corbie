import CloudKit
import CoreData
import Foundation
import Testing
@testable import CorbieCore

@Suite struct PersistenceStackTests {
    @Test func inMemoryStackLoadsWithoutCloudKit() {
        let stack = CoreDataStack(inMemoryAuthor: .tests)
        #expect(stack.loadFailure == nil)
        #expect(stack.mirroring == .disabled)
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
        #expect(PersistenceController.preview.stack.mirroring == .disabled)
    }

    @Test func extensionStacksOpenBothStoresWithHistoryAndWithoutMirroring() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let suiteName = "corbie-extension-stack-" + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let widgets = CoreDataStack(
            directory: directory,
            author: .widgets,
            mirroring: .disabled,
            historyDefaults: defaults,
            requiresAppGroup: false
        )
        #expect(widgets.loadFailure == nil)
        #expect(widgets.mirroring == .disabled)
        #expect(widgets.cloudKitContainer == nil)
        #expect((widgets.container is NSPersistentCloudKitContainer) == false)
        #expect(widgets.container.persistentStoreCoordinator.persistentStores.count == 2)
        for description in widgets.container.persistentStoreDescriptions {
            #expect(description.cloudKitContainerOptions == nil)
            #expect(description.options[NSPersistentHistoryTrackingKey] as? NSNumber == true)
            #expect(description.options[NSPersistentStoreRemoteChangeNotificationPostOptionKey] as? NSNumber == true)
        }

        let app = CoreDataStack(storesIn: directory, author: .app)
        let context = app.newBackgroundContext()
        try context.performAndWait {
            let space = Space(context: context)
            if let store = app.store(for: .privateStore) {
                context.assign(space, to: store)
            }
            try context.save()
        }
        _ = try widgets.processHistory()
        #expect(defaults.data(forKey: StoreReset.historyTokenKey(author: .widgets)) != nil)
        #expect(try widgets.processHistory() == 0)
    }

    @Test func onlyTheMirroringStackAsksCloudKitForBothScopes() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        let mirrored = CoreDataStack.storeDescriptions(in: directory, mirroring: .cloudKit)
        #expect(mirrored.map { $0.url?.lastPathComponent } == ["private.sqlite", "shared.sqlite"])
        #expect(mirrored.map { $0.cloudKitContainerOptions?.databaseScope } == [.private, .shared])
        #expect(mirrored.allSatisfy { $0.cloudKitContainerOptions?.containerIdentifier == CorbieIdentifiers.cloudKitContainer })
        let local = CoreDataStack.storeDescriptions(in: directory, mirroring: .disabled)
        #expect(local.allSatisfy { $0.cloudKitContainerOptions == nil })
        #expect(StoreMirroring.cloudKit.historyRetention == PersistentHistoryObserver.retention)
        #expect(StoreMirroring.disabled.historyRetention == nil)
    }

    @MainActor
    @Test func sharingRefusesAStackThatDoesNotMirror() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let sharing = CloudKitSharing(stack: CoreDataStack(storesIn: directory, author: .share))
        let notConfigured = CorbieError.cloudKit("CloudKit container is not configured")
        await #expect(throws: notConfigured) {
            try await sharing.leave(space: UUID(), memberId: UUID())
        }
        await #expect(throws: notConfigured) {
            _ = try await sharing.removeDepartedMembers(space: UUID(), ownerMemberId: UUID())
        }
        await #expect(throws: notConfigured) {
            try await sharing.purgePrivateZones()
        }
        #expect(throws: notConfigured) {
            _ = try sharing.existingShare(for: UUID())
        }
    }

    @Test func aMissingZoneCountsAsPurged() {
        #expect(CloudKitSharing.isMissingZone(CKError(.zoneNotFound)))
        #expect(CloudKitSharing.isMissingZone(CKError(.userDeletedZone)))
        #expect(CloudKitSharing.isMissingZone(CKError(.networkUnavailable)) == false)
        #expect(CloudKitSharing.isMissingZone(CorbieError.cloudKit("zone")) == false)
        let partial = CKError(.partialFailure, userInfo: [
            CKPartialErrorsByItemIDKey: [CloudKitSharing.defaultZoneID: CKError(.zoneNotFound)]
        ])
        #expect(CloudKitSharing.isMissingZone(partial))
        let mixed = CKError(.partialFailure, userInfo: [
            CKPartialErrorsByItemIDKey: [
                CloudKitSharing.defaultZoneID: CKError(.zoneNotFound),
                CKRecordZone.ID(zoneName: "other", ownerName: CKCurrentUserDefaultName): CKError(.quotaExceeded)
            ]
        ])
        #expect(CloudKitSharing.isMissingZone(mixed) == false)
    }

    @Test func schemaInitialisationOnlyRunsWhenItIsRequested() throws {
        let stack = CoreDataStack(inMemoryAuthor: .tests)
        try stack.initializeCloudKitSchemaIfRequested(isRequested: false)
        #expect(stack.cloudKitContainer == nil)
        #if DEBUG
        #expect(throws: CorbieError.cloudKit("CloudKit container is not configured")) {
            try stack.initializeCloudKitSchemaIfRequested(isRequested: true)
        }
        #endif
    }

    private func makeDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("corbie-stack-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
