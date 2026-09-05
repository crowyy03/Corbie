import CloudKit
import CoreData
import Foundation

@MainActor
public final class CloudKitSharing {
    public static let shareTitle = "Corbie"

    private let stack: CoreDataStack

    public init(stack: CoreDataStack) {
        self.stack = stack
    }

    public func share(space spaceId: UUID) async throws -> CKShare {
        let container = try cloudKitContainer()
        if let existing = try existingShare(for: spaceId) { return existing }
        guard let space = try space(with: spaceId, in: stack.viewContext) else {
            throw CorbieError.notFound("space \(spaceId)")
        }
        guard let store = stack.store(for: .privateStore) else {
            throw CorbieError.cloudKit("private store is not loaded")
        }
        do {
            let result = try await container.share([space], to: nil)
            let share = result.1
            share[CKShare.SystemFieldKey.title] = CloudKitSharing.shareTitle
            share.publicPermission = .none
            return try await container.persistUpdatedShare(share, in: store)
        } catch let error as CorbieError {
            throw error
        } catch {
            throw CorbieError.cloudKit(error.localizedDescription)
        }
    }

    public func existingShare(for spaceId: UUID) throws -> CKShare? {
        let container = try cloudKitContainer()
        guard let space = try space(with: spaceId, in: stack.viewContext) else { return nil }
        do {
            return try container.fetchShares(matching: [space.objectID])[space.objectID]
        } catch {
            throw CorbieError.cloudKit(error.localizedDescription)
        }
    }

    public func acceptShare(metadata: CKShare.Metadata) async throws {
        let container = try cloudKitContainer()
        guard let store = sharedStore() else {
            throw CorbieError.cloudKit("shared store is not loaded")
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            container.acceptShareInvitations(from: [metadata], into: store) { _, error in
                if let error {
                    continuation.resume(throwing: CorbieError.cloudKit(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    public func fetchShareMetadata(from url: URL) async throws -> CKShare.Metadata {
        let operation = CKFetchShareMetadataOperation(shareURLs: [url])
        operation.shouldFetchRootRecord = true
        return try await withCheckedThrowingContinuation { continuation in
            let box = SingleResultBox<CKShare.Metadata>()
            operation.perShareMetadataResultBlock = { _, result in
                if case let .success(metadata) = result {
                    box.value = metadata
                }
            }
            operation.fetchShareMetadataResultBlock = { result in
                switch result {
                case .success:
                    if let metadata = box.value {
                        continuation.resume(returning: metadata)
                    } else {
                        continuation.resume(throwing: CorbieError.cloudKit("share metadata is missing"))
                    }
                case let .failure(error):
                    continuation.resume(throwing: CorbieError.cloudKit(error.localizedDescription))
                }
            }
            CKContainer(identifier: CorbieIdentifiers.cloudKitContainer).add(operation)
        }
    }

    public nonisolated func currentSpace(
        in context: NSManagedObjectContext,
        currentMemberId: UUID? = nil
    ) throws -> Space? {
        let sharedIdentifier = sharedStore()?.identifier
        return try context.performAndWait {
            let request = NSFetchRequest<Space>(entityName: Space.entityName)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            let spaces: [Space]
            do {
                spaces = try context.fetch(request)
            } catch {
                throw CorbieError.persistence(error.localizedDescription)
            }
            let joined = spaces.filter { space in
                guard let sharedIdentifier else { return false }
                return space.objectID.persistentStore?.identifier == sharedIdentifier
            }
            if let currentMemberId,
               let mine = joined.first(where: { space in
                   space.members.contains { $0.id == currentMemberId }
               }) {
                return mine
            }
            if let first = joined.first { return first }
            if let paired = spaces.first(where: { $0.members.count >= 2 }) { return paired }
            if let currentMemberId,
               let owned = spaces.first(where: { $0.creatorMemberId == currentMemberId }) {
                return owned
            }
            return spaces.first
        }
    }

    public func leave(space spaceId: UUID) async throws {
        let container = try cloudKitContainer()
        guard let shared = sharedStore() else {
            throw CorbieError.cloudKit("shared store is not loaded")
        }
        guard let space = try space(with: spaceId, in: stack.viewContext) else {
            throw CorbieError.notFound("space \(spaceId)")
        }
        guard space.objectID.persistentStore === shared else {
            throw CorbieError.cloudKit("space \(spaceId) is owned here, delete it instead of leaving it")
        }
        guard let share = try existingShare(for: spaceId) else {
            throw CorbieError.cloudKit("space \(spaceId) has no share to leave")
        }
        let database = CKContainer(identifier: CorbieIdentifiers.cloudKitContainer).sharedCloudDatabase
        do {
            _ = try await database.deleteRecord(withID: share.recordID)
        } catch {
            throw CorbieError.cloudKit(error.localizedDescription)
        }
        try await purgeZone(share.recordID.zoneID, in: shared, container: container)
    }

    public func deleteSpace(space spaceId: UUID) async throws {
        guard let space = try space(with: spaceId, in: stack.viewContext) else {
            throw CorbieError.notFound("space \(spaceId)")
        }
        if let shared = sharedStore(), space.objectID.persistentStore === shared {
            throw CorbieError.cloudKit("space \(spaceId) belongs to your partner, leave it instead of deleting it")
        }
        if let share = try existingShare(for: spaceId) {
            let database = CKContainer(identifier: CorbieIdentifiers.cloudKitContainer).privateCloudDatabase
            do {
                _ = try await database.deleteRecord(withID: share.recordID)
            } catch {
                throw CorbieError.cloudKit(error.localizedDescription)
            }
        }
        try deleteLocalSpace(spaceId)
    }

    private func purgeZone(
        _ zoneID: CKRecordZone.ID,
        in store: NSPersistentStore,
        container: NSPersistentCloudKitContainer
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            container.purgeObjectsAndRecordsInZone(with: zoneID, in: store) { _, error in
                if let error {
                    continuation.resume(throwing: CorbieError.cloudKit(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    private nonisolated func sharedStore() -> NSPersistentStore? {
        guard let shared = stack.store(for: .sharedStore),
              shared !== stack.store(for: .privateStore) else {
            return nil
        }
        return shared
    }

    private func deleteLocalSpace(_ spaceId: UUID) throws {
        let context = stack.viewContext
        try context.performAndWait {
            guard let space = try space(with: spaceId, in: context) else { return }
            context.delete(space)
            do {
                try context.save()
            } catch {
                throw CorbieError.persistence(error.localizedDescription)
            }
        }
    }

    private nonisolated func space(with spaceId: UUID, in context: NSManagedObjectContext) throws -> Space? {
        let request = NSFetchRequest<Space>(entityName: Space.entityName)
        request.predicate = NSPredicate(format: "id == %@", spaceId as NSUUID)
        request.fetchLimit = 1
        do {
            return try context.fetch(request).first
        } catch {
            throw CorbieError.persistence(error.localizedDescription)
        }
    }

    private func cloudKitContainer() throws -> NSPersistentCloudKitContainer {
        guard stack.isCloudKitEnabled, let container = stack.cloudKitContainer else {
            throw CorbieError.cloudKit("CloudKit container is not configured")
        }
        return container
    }
}

private final class SingleResultBox<Value> {
    var value: Value?
}
