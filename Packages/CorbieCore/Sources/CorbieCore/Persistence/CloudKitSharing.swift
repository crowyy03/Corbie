import CloudKit
import CoreData
import CryptoKit
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

    private nonisolated static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "pairing")

    public let environment: CloudKitEnvironment?

    private let stack: CoreDataStack
    private let members: CoreDataMemberRepository
    private let exportTimeout: Duration

    public init(
        stack: CoreDataStack,
        exportTimeout: Duration = CloudKitSharing.memberExportTimeout,
        environment: CloudKitEnvironment? = CloudKitEnvironment.declared()
    ) {
        self.stack = stack
        self.exportTimeout = exportTimeout
        self.environment = environment
        members = CoreDataMemberRepository(stack: stack)
    }

    public func share(space spaceId: UUID) async throws -> CKShare {
        let container = try cloudKitContainer()
        guard let space = try space(with: spaceId, in: stack.viewContext) else {
            throw CorbieError.notFound("space \(spaceId)")
        }
        guard let store = stack.store(for: .privateStore) else {
            throw CorbieError.cloudKit("private store is not loaded")
        }
        guard space.objectID.persistentStore === store else {
            throw CorbieError.cloudKit("space \(spaceId) is shared with this phone, only its owner can invite")
        }
        let known = try knownShare(of: space, in: container)
        do {
            guard let known else {
                let created = try await createShare(for: space, in: store, container: container)
                logShare(created, spaceId: spaceId, origin: "created")
                return created
            }
            let database = CKContainer(identifier: CorbieIdentifiers.cloudKitContainer).privateCloudDatabase
            if let live = try await serverShare(known.recordID, in: database) {
                logShare(live, spaceId: spaceId, origin: "checked on the server")
                return live
            }
            CloudKitSharing.log.error(
                """
                share \(known.recordID.recordName, privacy: .public) of space \(spaceId, privacy: .public) \
                is gone from the server, saving a new one in zone \(known.recordID.zoneID.zoneName, privacy: .public)
                """
            )
            let recreated = try await recreateShare(in: known.recordID.zoneID, store: store, container: container)
            logShare(recreated, spaceId: spaceId, origin: "made again")
            return recreated
        } catch let failure as CloudKitFailure {
            CloudKitSharing.log.error("\(failure.failureReason ?? "", privacy: .public) environment \(self.environmentName, privacy: .public)")
            throw failure
        } catch {
            let failure = CloudKitFailure(step: "share create", error: error)
            CloudKitSharing.log.error("\(failure.failureReason ?? "", privacy: .public) environment \(self.environmentName, privacy: .public)")
            throw failure
        }
    }

    public func inviteOrigin() async -> InviteOrigin {
        InviteOrigin(environment: environment, iCloudAccount: await accountFingerprint())
    }

    public func accountFingerprint() async -> String? {
        do {
            let me = try await CKContainer(identifier: CorbieIdentifiers.cloudKitContainer).userRecordID()
            return CloudKitSharing.fingerprint(ofAccount: me.recordName)
        } catch {
            let failure = CloudKitFailure(step: "read the iCloud user", error: error)
            CloudKitSharing.log.error("\(failure.failureReason ?? "", privacy: .public)")
            return nil
        }
    }

    public nonisolated static func fingerprint(ofAccount recordName: String) -> String {
        SHA256.hash(data: Data(recordName.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    public func existingShare(for spaceId: UUID) throws -> CKShare? {
        let container = try cloudKitContainer()
        guard let space = try space(with: spaceId, in: stack.viewContext) else { return nil }
        return try knownShare(of: space, in: container)
    }

    public func acceptShare(metadata: CKShare.Metadata) async throws {
        let container = try cloudKitContainer()
        guard let store = sharedStore() else {
            throw CorbieError.cloudKit("shared store is not loaded")
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            container.acceptShareInvitations(from: [metadata], into: store) { _, error in
                if let error {
                    let failure = CloudKitFailure(step: "accept share", error: error)
                    CloudKitSharing.log.error("\(failure.failureReason ?? "", privacy: .public)")
                    continuation.resume(throwing: failure)
                } else {
                    CloudKitSharing.log.notice("share accepted")
                    continuation.resume()
                }
            }
        }
    }

    public func fetchShareMetadata(from url: URL) async throws -> CKShare.Metadata {
        let link = ShareLinkLog.text(for: url)
        let environmentName = self.environmentName
        CloudKitSharing.log.notice(
            "fetch share metadata: url \(link, privacy: .public) environment \(environmentName, privacy: .public)"
        )
        let operation = CKFetchShareMetadataOperation(shareURLs: [url])
        operation.shouldFetchRootRecord = true
        return try await withCheckedThrowingContinuation { continuation in
            let box = SingleResultBox<Result<CKShare.Metadata, any Error>>()
            operation.perShareMetadataResultBlock = { _, result in
                box.value = result
            }
            operation.fetchShareMetadataResultBlock = { result in
                let failure: CloudKitFailure
                switch (result, box.value) {
                case let (_, .success(metadata)?):
                    continuation.resume(returning: metadata)
                    return
                case let (_, .failure(error)?):
                    failure = CloudKitFailure(step: "fetch share metadata", error: error)
                case let (.failure(error), nil):
                    failure = CloudKitFailure(step: "fetch share metadata", error: error)
                case (.success, nil):
                    failure = CloudKitFailure(
                        step: "fetch share metadata",
                        reason: .other,
                        detail: "CloudKit finished without an answer for the link"
                    )
                }
                CloudKitSharing.log.error(
                    """
                    \(failure.failureReason ?? "", privacy: .public) url \(link, privacy: .public) \
                    environment \(environmentName, privacy: .public)
                    """
                )
                continuation.resume(throwing: failure)
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
            CloudKitSharing.log.info("space \(spaceId, privacy: .public) is not stored here any more, nothing to leave")
            return
        }
        guard space.objectID.persistentStore === shared else {
            throw CorbieError.cloudKit("space \(spaceId) is owned here, delete it instead of leaving it")
        }
        guard let share = try existingShare(for: spaceId) else {
            throw CorbieError.cloudKit("space \(spaceId) has no share to leave")
        }
        let database = CKContainer(identifier: CorbieIdentifiers.cloudKitContainer).sharedCloudDatabase
        if try await serverShare(share.recordID, in: database) != nil {
            try await removeOwnMember(memberId, spaceId: spaceId, store: shared)
            do {
                _ = try await database.deleteRecord(withID: share.recordID)
            } catch let error as CKError where CloudKitSharing.isMissingRecord(error) {
                CloudKitSharing.log.info("the share of space \(spaceId, privacy: .public) was already gone")
            } catch {
                throw CorbieError.cloudKit(error.localizedDescription)
            }
        }
        try await purgeZone(
            share.recordID.zoneID,
            in: shared,
            container: container,
            reason: .leave,
            missingZoneIsPurged: true
        )
    }

    public func removeDepartedMembers(space spaceId: UUID, ownerMemberId: UUID) async throws -> [UUID] {
        _ = try cloudKitContainer()
        guard let privateStore = stack.store(for: .privateStore),
              let space = try space(with: spaceId, in: stack.viewContext),
              space.objectID.persistentStore === privateStore
        else { return [] }
        let spaceMembers = try await members.members(spaceId: spaceId)
        guard spaceMembers.contains(where: { $0.id != ownerMemberId }) else { return [] }
        guard let share = try existingShare(for: spaceId) else { return [] }
        let database = CKContainer(identifier: CorbieIdentifiers.cloudKitContainer).privateCloudDatabase
        guard let current = try await serverShare(share.recordID, in: database) else { return [] }
        let departed = DepartedMemberRule.memberIdsToRemove(
            ownerMemberId: ownerMemberId,
            members: spaceMembers,
            participants: current.participants.map(ShareParticipantSummary.init)
        )
        guard departed.isEmpty == false else { return [] }
        try await members.removeMembersAndFreeTheirTasks(ids: departed, spaceId: spaceId)
        CloudKitSharing.log.info("removed \(departed.count) members who left space \(spaceId, privacy: .public)")
        return departed
    }

    public enum ICloudAccount: Sendable, Equatable {
        case available
        case missing
        case busy
        case unknown
    }

    public func iCloudAccount() async -> ICloudAccount {
        guard let status = try? await CKContainer(identifier: CorbieIdentifiers.cloudKitContainer).accountStatus()
        else { return .unknown }
        switch status {
        case .available: return .available
        case .noAccount, .restricted: return .missing
        case .temporarilyUnavailable: return .busy
        case .couldNotDetermine: return .unknown
        @unknown default: return .unknown
        }
    }

    public func isICloudAccountMissing() async -> Bool {
        await iCloudAccount() == .missing
    }

    public func isOwnShare(_ metadata: CKShare.Metadata) async -> Bool {
        let container = CKContainer(identifier: CorbieIdentifiers.cloudKitContainer)
        guard let me = try? await container.userRecordID() else { return false }
        return metadata.ownerIdentity.userRecordID == me
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
                try await purgeZone(
                    zoneID,
                    in: privateStore,
                    container: container,
                    reason: .deleteAccount,
                    missingZoneIsPurged: true
                )
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

    private func serverShare(_ recordID: CKRecord.ID, in database: CKDatabase) async throws -> CKShare? {
        let record: CKRecord
        do {
            record = try await database.record(for: recordID)
        } catch let error as CKError where CloudKitSharing.isMissingRecord(error) {
            return nil
        } catch {
            throw CloudKitFailure(step: "share check", error: error)
        }
        guard let share = record as? CKShare else {
            throw CorbieError.cloudKit("record \(recordID.recordName) is not a share")
        }
        return share
    }

    private func knownShare(of space: Space, in container: NSPersistentCloudKitContainer) throws -> CKShare? {
        do {
            return try container.fetchShares(matching: [space.objectID])[space.objectID]
        } catch {
            throw CorbieError.cloudKit(error.localizedDescription)
        }
    }

    private func createShare(
        for space: Space,
        in store: NSPersistentStore,
        container: NSPersistentCloudKitContainer
    ) async throws -> CKShare {
        let (_, share, _) = try await container.share([space], to: nil)
        share[CKShare.SystemFieldKey.title] = CloudKitSharing.shareTitle
        share.publicPermission = .readWrite
        return try await container.persistUpdatedShare(share, in: store)
    }

    private func recreateShare(
        in zoneID: CKRecordZone.ID,
        store: NSPersistentStore,
        container: NSPersistentCloudKitContainer
    ) async throws -> CKShare {
        let share = CKShare(recordZoneID: zoneID)
        share[CKShare.SystemFieldKey.title] = CloudKitSharing.shareTitle
        share.publicPermission = .readWrite
        do {
            return try await container.persistUpdatedShare(share, in: store)
        } catch {
            throw CloudKitFailure(step: "share make again", error: error)
        }
    }

    private var environmentName: String {
        environment?.rawValue ?? "undeclared"
    }

    private func logShare(_ share: CKShare, spaceId: UUID, origin: String) {
        let link = share.url.map(ShareLinkLog.text(for:)) ?? "pending"
        CloudKitSharing.log.notice(
            """
            invite share \(origin, privacy: .public): space \(spaceId, privacy: .public) \
            record \(share.recordID.recordName, privacy: .public) zone \(share.recordID.zoneID.zoneName, privacy: .public) \
            url \(link, privacy: .public) environment \(self.environmentName, privacy: .public)
            """
        )
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
        reason: ZonePurgeReason,
        missingZoneIsPurged: Bool = false
    ) async throws {
        let label = StoreScope.allCases.first { stack.store(for: $0) === store }?.rawValue ?? SyncLog.unknown
        let zoneName = zoneID.zoneName
        SyncLog.write(SyncLog.purgeAskedLine(store: label, zone: zoneName, reason: reason))
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            container.purgeObjectsAndRecordsInZone(with: zoneID, in: store) { _, error in
                let countsAsPurged = error.map { missingZoneIsPurged && CloudKitSharing.isMissingZone($0) } ?? true
                SyncLog.write(SyncLog.purgeResultLine(
                    store: label,
                    zone: zoneName,
                    reason: reason,
                    error: error,
                    zoneWasMissing: error != nil && countsAsPurged
                ))
                if let error, countsAsPurged == false {
                    continuation.resume(throwing: CorbieError.cloudKit(error.localizedDescription))
                } else {
                    continuation.resume()
                }
            }
        }
    }

    nonisolated static func isMissingRecord(_ error: any Error) -> Bool {
        guard let error = error as? CKError else { return false }
        return error.code == .unknownItem || isMissingZone(error)
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
