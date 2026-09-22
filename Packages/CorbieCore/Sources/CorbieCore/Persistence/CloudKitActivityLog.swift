import CloudKit
import CoreData
import Foundation

final class CloudKitActivityLog: @unchecked Sendable {
    typealias EventReader = @Sendable (Notification) -> CloudKitMirroringEvent?
    typealias RecordZones = ([NSManagedObjectID]) -> [NSManagedObjectID: String]
    typealias ShareZones = (NSPersistentStore) -> [String]
    typealias Writer = @Sendable (SyncLogEntry) -> Void

    private let container: NSPersistentContainer
    private let defaults: UserDefaults
    private let center: NotificationCenter
    private let recordZones: RecordZones
    private let shareZones: ShareZones
    private let write: Writer
    private let modelEntities: Set<String>
    private let queue = DispatchQueue(label: CorbieIdentifiers.bundleID + ".sync-log")
    private let lock = NSLock()
    private var observer: (any NSObjectProtocol)?
    private var isStarted = false
    private var waiting: [CloudKitMirroringEvent] = []
    private var storesWithZonesLogged: Set<String> = []

    init(
        container: NSPersistentContainer,
        defaults: UserDefaults,
        center: NotificationCenter = .default,
        readEvent: @escaping EventReader = { CloudKitMirroringEvent(notification: $0) },
        recordZones: @escaping RecordZones,
        shareZones: @escaping ShareZones,
        write: @escaping Writer = { SyncLog.write($0) }
    ) {
        self.container = container
        self.defaults = defaults
        self.center = center
        self.recordZones = recordZones
        self.shareZones = shareZones
        self.write = write
        modelEntities = Set(container.managedObjectModel.entitiesByName.keys)
        let token = center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let event = readEvent(notification), event.endedAt != nil else { return }
            self?.enqueue(event)
        }
        lock.withLock { observer = token }
    }

    static func mirroring(_ container: NSPersistentContainer, defaults: UserDefaults) -> CloudKitActivityLog? {
        guard let cloudKit = container as? NSPersistentCloudKitContainer else { return nil }
        return CloudKitActivityLog(
            container: cloudKit,
            defaults: defaults,
            recordZones: { ids in cloudKit.recordIDs(for: ids).mapValues(\.zoneID.zoneName) },
            shareZones: { store in ((try? cloudKit.fetchShares(in: store)) ?? []).map(\.recordID.zoneID.zoneName) }
        )
    }

    deinit {
        let token = lock.withLock { observer }
        if let token {
            center.removeObserver(token)
        }
    }

    static func tokenKey(_ direction: SyncDirection, _ scope: StoreScope) -> String {
        "sync.log.token.\(direction.rawValue).\(scope.rawValue)"
    }

    static var tokenKeys: [String] {
        SyncDirection.allCases.flatMap { direction in StoreScope.allCases.map { tokenKey(direction, $0) } }
    }

    func start() {
        markMissingTokens()
        lock.withLock {
            isStarted = true
            for event in waiting {
                queue.async { self.record(event) }
            }
            waiting = []
        }
    }

    func record(_ event: CloudKitMirroringEvent) {
        guard event.endedAt != nil else { return }
        let store = persistentStore(identifier: event.storeIdentifier)
        let scope = store.flatMap(CloudKitActivityLog.scope(of:))
        let label = scope?.rawValue ?? SyncLog.unknown
        switch event.kind {
        case .setup:
            guard event.succeeded else {
                emit(SyncLog.failureLines("setup", store: label, report: event.errorReport))
                return
            }
            emit([.notice("setup ok store=\(label)")])
            if let store {
                logZonesOnce(of: store, label: label)
            }
        case .exporting, .importing:
            guard let direction = SyncDirection(event.kind) else { return }
            guard event.succeeded else {
                emit(SyncLog.failureLines(direction.rawValue, store: label, report: event.errorReport))
                return
            }
            guard let store, let scope else {
                emit([.notice("\(direction.rawValue) ok store=\(label)")])
                return
            }
            logChanges(direction, in: store, scope: scope, until: direction == .exporting ? event.startedAt : nil)
        case .unknown:
            return
        }
    }

    private func enqueue(_ event: CloudKitMirroringEvent) {
        lock.withLock {
            if isStarted {
                queue.async { self.record(event) }
            } else {
                waiting.append(event)
            }
        }
    }

    private func logChanges(_ direction: SyncDirection, in store: NSPersistentStore, scope: StoreScope, until: Date?) {
        let key = CloudKitActivityLog.tokenKey(direction, scope)
        let storeIdentifier = store.identifier
        let context = container.newBackgroundContext()
        let batch: SyncHistoryBatch
        do {
            batch = try context.performAndWait {
                try SyncHistoryBatch.read(
                    store: persistentStore(identifier: storeIdentifier),
                    after: storedToken(forKey: key),
                    direction: direction,
                    until: until,
                    entities: modelEntities,
                    in: context
                )
            }
        } catch let error as NSError where CloudKitActivityLog.isExpiredToken(error) {
            save(currentToken(of: store), forKey: key)
            emit([.notice("\(direction.rawValue) history restarted store=\(scope.rawValue) reason=expired")])
            return
        } catch {
            let failure = error as NSError
            emit([.error(
                "\(direction.rawValue) history unreadable store=\(scope.rawValue) "
                    + "domain=\(failure.domain) code=\(failure.code)"
            )])
            return
        }
        save(batch.token, forKey: key)
        let objectIDs = Array(Set(batch.changes.map(\.objectID)))
        let zones = objectIDs.isEmpty ? [:] : recordZones(objectIDs)
        emit(SyncLog.changeLines(direction, store: scope.rawValue, changes: batch.changes, zones: zones))
    }

    private func logZonesOnce(of store: NSPersistentStore, label: String) {
        guard let identifier = store.identifier,
              lock.withLock({ storesWithZonesLogged.insert(identifier).inserted })
        else { return }
        let context = container.newBackgroundContext()
        let spaceIDs: [NSManagedObjectID] = context.performAndWait {
            guard let store = persistentStore(identifier: identifier) else { return [] }
            let request = NSFetchRequest<NSManagedObjectID>(entityName: Space.entityName)
            request.resultType = .managedObjectIDResultType
            request.affectedStores = [store]
            return (try? context.fetch(request)) ?? []
        }
        let zones = spaceIDs.isEmpty ? [:] : recordZones(spaceIDs)
        let spaces = spaceIDs.map { zones[$0] ?? SyncLog.unknown }
        emit([SyncLog.zonesLine(store: label, spaces: spaces, shares: shareZones(store))])
    }

    private func markMissingTokens() {
        let coordinator = container.persistentStoreCoordinator
        for store in coordinator.persistentStores {
            guard let scope = CloudKitActivityLog.scope(of: store),
                  let current = coordinator.currentPersistentHistoryToken(fromStores: [store])
            else { continue }
            for direction in SyncDirection.allCases {
                let key = CloudKitActivityLog.tokenKey(direction, scope)
                if defaults.data(forKey: key) == nil {
                    save(current, forKey: key)
                }
            }
        }
    }

    private func emit(_ entries: [SyncLogEntry]) {
        entries.forEach(write)
    }

    private func persistentStore(identifier: String?) -> NSPersistentStore? {
        guard let identifier else { return nil }
        return container.persistentStoreCoordinator.persistentStores.first { $0.identifier == identifier }
    }

    private func currentToken(of store: NSPersistentStore) -> NSPersistentHistoryToken? {
        container.persistentStoreCoordinator.currentPersistentHistoryToken(fromStores: [store])
    }

    private func storedToken(forKey key: String) -> NSPersistentHistoryToken? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self, from: data)
    }

    private func save(_ token: NSPersistentHistoryToken?, forKey key: String) {
        guard let token,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        else { return }
        defaults.set(data, forKey: key)
    }

    private static func scope(of store: NSPersistentStore) -> StoreScope? {
        StoreScope.allCases.first { $0.fileName == store.url?.lastPathComponent }
    }

    private static func isExpiredToken(_ error: NSError) -> Bool {
        error.domain == NSCocoaErrorDomain && error.code == NSPersistentHistoryTokenExpiredError
    }
}

struct SyncHistoryBatch {
    var changes: [SyncedChange] = []
    var token: NSPersistentHistoryToken?

    static func read(
        store: NSPersistentStore?,
        after token: NSPersistentHistoryToken?,
        direction: SyncDirection,
        until: Date?,
        entities: Set<String>,
        in context: NSManagedObjectContext
    ) throws -> SyncHistoryBatch {
        guard let store else { return SyncHistoryBatch() }
        let request = NSPersistentHistoryChangeRequest.fetchHistory(after: token)
        request.affectedStores = [store]
        let result = try context.execute(request) as? NSPersistentHistoryResult
        let transactions = result?.result as? [NSPersistentHistoryTransaction] ?? []
        var batch = SyncHistoryBatch()
        for transaction in transactions {
            if let until, transaction.timestamp > until { break }
            batch.token = transaction.token
            guard direction.carries(author: transaction.author) else { continue }
            for change in transaction.changes ?? [] {
                guard let entityName = change.changedObjectID.entity.name,
                      entities.contains(entityName),
                      touchesOnlyChildren(change) == false
                else { continue }
                batch.changes.append(
                    SyncedChange(objectID: change.changedObjectID, entityName: entityName, type: changeType(change.changeType))
                )
            }
        }
        return batch
    }

    private static func touchesOnlyChildren(_ change: NSPersistentHistoryChange) -> Bool {
        guard change.changeType == .update, let properties = change.updatedProperties, properties.isEmpty == false else {
            return false
        }
        return properties.allSatisfy { ($0 as? NSRelationshipDescription)?.isToMany == true }
    }

    private static func changeType(_ raw: NSPersistentHistoryChangeType) -> RemoteChangeType {
        switch raw {
        case .insert: return .insert
        case .update: return .update
        case .delete: return .delete
        @unknown default: return .update
        }
    }
}
