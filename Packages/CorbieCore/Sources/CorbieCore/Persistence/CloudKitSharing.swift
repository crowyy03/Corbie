import CloudKit
import CoreData
import Foundation
import os

@MainActor
public final class CloudKitSharing {
    public static let shareTitle = "Corbie"
    public nonisolated static let memberExportTimeout = Duration.seconds(20)

    nonisolated static let defaultZoneID = CKRecordZone.ID(
        zoneName: "com.apple.coredata.cloudkit.zone",
        ownerName: CKCurrentUserDefaultName
    )

    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "sharing")

    private let stack: CoreDataStack
    private let members: CoreDataMemberRepository
    private let exportTimeout: Duration

    public init(stack: CoreDataStack, exportTimeout: Duration = CloudKitSharing.memberExportTimeout) {
        self.stack = stack
        self.exportTimeout = exportTimeout
        members = CoreDataMemberRepository(stack: stack)
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
            share.publicPermission = .readWrite
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

    public func leave(space spaceId: UUID, memberId: UUID) async throws {
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
        _ = try await serverShare(share.recordID, in: database)
        try await removeOwnMember(memberId, spaceId: spaceId, store: shared)
        do {
            _ = try await database.deleteRecord(withID: share.recordID)
        } catch {
            throw CorbieError.cloudKit(error.localizedDescription)
        }
        try await purgeZone(share.recordID.zoneID, in: shared, container: container)
    }

    public func removeDepartedMembers(space spaceId: UUID, ownerMemberId: UUID) async throws -> [UUID] {
        _ = try cloudKitContainer()
        guard let privateStore = stack.store(for: .privateStore),
              let space = try space(with: spaceId, in: stack.viewContext),
              space.objectID.persistentStore === privateStore
        else { return [] }
        let memberIds = try await members.members(spaceId: spaceId).map(\.id)
        guard memberIds.contains(where: { $0 != ownerMemberId }) else { return [] }
        guard let share = try existingShare(for: spaceId) else { return [] }
        let database = CKContainer(identifier: CorbieIdentifiers.cloudKitContainer).privateCloudDatabase
        let current = try await serverShare(share.recordID, in: database)
        let departed = DepartedMemberRule.memberIdsToRemove(
            ownerMemberId: ownerMemberId,
            memberIds: memberIds,
            participants: current.participants.map(ShareParticipantSummary.init)
        )
        guard departed.isEmpty == false else { return [] }
        try await members.removeMembersAndFreeTheirTasks(ids: departed, spaceId: spaceId)
        CloudKitSharing.log.info("removed \(departed.count) members who left space \(spaceId, privacy: .public)")
        return departed
    }

    public func purgePrivateZones() async throws {
        let container = try cloudKitContainer()
        guard let privateStore = stack.store(for: .privateStore) else {
            throw CorbieError.cloudKit("private store is not loaded")
        }
        var zoneIDs = try spaceZoneIDs(in: privateStore, container: container)
        if zoneIDs.contains(CloudKitSharing.defaultZoneID) == false {
            zoneIDs.append(CloudKitSharing.defaultZoneID)
        }
        var firstFailure: (any Error)?
        for zoneID in zoneIDs {
            do {
                try await purgeZone(zoneID, in: privateStore, container: container, missingZoneIsPurged: true)
            } catch {
                CloudKitSharing.log.error(
                    "purging \(zoneID.zoneName, privacy: .public) failed: \(error.localizedDescription, privacy: .public)"
                )
                firstFailure = firstFailure ?? error
            }
        }
        if let firstFailure {
            throw firstFailure
        }
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

    private func removeOwnMember(_ memberId: UUID, spaceId: UUID, store: NSPersistentStore) async throws {
        let export = CloudKitSyncWait(
            kind: .exporting,
            storeIdentifier: store.identifier ?? "",
            startedAtOrAfter: Date()
        )
        let removed = try await members.removeMembersAndFreeTheirTasks(ids: [memberId], spaceId: spaceId)
        guard removed > 0 else { return }
        let outcome = await export.outcome(within: exportTimeout)
        guard outcome != .finished else { return }
        CloudKitSharing.log.error(
            "leaving before the member removal was exported: \(String(describing: outcome), privacy: .public)"
        )
    }

    private func serverShare(_ recordID: CKRecord.ID, in database: CKDatabase) async throws -> CKShare {
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch {
            throw CorbieError.cloudKit(error.localizedDescription)
        }
        guard let share = record as? CKShare else {
            throw CorbieError.cloudKit("record \(recordID.recordName) is not a share")
        }
        return share
    }

    private func spaceZoneIDs(
        in store: NSPersistentStore,
        container: NSPersistentCloudKitContainer
    ) throws -> [CKRecordZone.ID] {
        let request = NSFetchRequest<Space>(entityName: Space.entityName)
        request.affectedStores = [store]
        let spaces: [Space]
        do {
            spaces = try stack.viewContext.fetch(request)
        } catch {
            throw CorbieError.persistence(error.localizedDescription)
        }
        var zoneIDs: [CKRecordZone.ID] = []
        for space in spaces {
            guard let zoneID = container.recordID(for: space.objectID)?.zoneID,
                  zoneIDs.contains(zoneID) == false
            else { continue }
            zoneIDs.append(zoneID)
        }
        return zoneIDs
    }

    private func purgeZone(
        _ zoneID: CKRecordZone.ID,
        in store: NSPersistentStore,
        container: NSPersistentCloudKitContainer,
        missingZoneIsPurged: Bool = false
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            container.purgeObjectsAndRecordsInZone(with: zoneID, in: store) { _, error in
                if let error, (missingZoneIsPurged && CloudKitSharing.isMissingZone(error)) == false {
                    continuation.resume(throwing: CorbieError.cloudKit(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    nonisolated static func isMissingZone(_ error: any Error) -> Bool {
        guard let error = error as? CKError else { return false }
        switch error.code {
        case .zoneNotFound, .userDeletedZone:
            return true
        case .partialFailure:
            guard let partial = error.partialErrorsByItemID, partial.isEmpty == false else { return false }
            return partial.values.allSatisfy(isMissingZone)
        default:
            return false
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
        guard let container = stack.cloudKitContainer else {
            throw CorbieError.cloudKit("CloudKit container is not configured")
        }
        return container
    }
}

private final class SingleResultBox<Value> {
    var value: Value?
}

extension ShareParticipantSummary {
    init(_ participant: CKShare.Participant) {
        let acceptance: Acceptance
        switch participant.acceptanceStatus {
        case .accepted: acceptance = .accepted
        case .pending: acceptance = .pending
        case .removed: acceptance = .removed
        case .unknown: acceptance = .unknown
        @unknown default: acceptance = .unknown
        }
        self.init(isOwner: participant.role == .owner, acceptance: acceptance)
    }
}
