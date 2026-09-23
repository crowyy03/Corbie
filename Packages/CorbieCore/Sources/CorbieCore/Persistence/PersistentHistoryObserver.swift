import CoreData
import Foundation
import os

final class PersistentHistoryObserver: @unchecked Sendable {
    typealias CleanupCutoff = @Sendable (_ storeIdentifiers: [String]) -> Date?

    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "history")

    private let container: NSPersistentContainer
    private let author: TransactionAuthor
    private let defaults: UserDefaults
    private let changes: StoreChanges?
    private let cleanupCutoff: CleanupCutoff?
    private let holdsRecordsUntilHandled: Bool
    private let lock = NSLock()
    private var observer: (any NSObjectProtocol)?
    private var handler: (@Sendable ([RemoteChangeRecord]) -> Void)?
    private var heldRecords: [RemoteChangeRecord] = []

    init(
        container: NSPersistentContainer,
        author: TransactionAuthor,
        defaults: UserDefaults = .corbieShared,
        changes: StoreChanges? = nil,
        cleanupCutoff: CleanupCutoff? = nil,
        holdsRecordsUntilHandled: Bool = false
    ) {
        self.container = container
        self.author = author
        self.defaults = defaults
        self.changes = changes
        self.cleanupCutoff = cleanupCutoff
        self.holdsRecordsUntilHandled = holdsRecordsUntilHandled
    }

    var tokenKey: String { StoreReset.historyTokenKey(author: author) }

    var storedToken: NSPersistentHistoryToken? {
        guard let data = defaults.data(forKey: tokenKey) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self, from: data)
    }

    func start() {
        lock.lock()
        defer { lock.unlock() }
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            do {
                _ = try process()
            } catch {
                PersistentHistoryObserver.log.error(
                    "history merge failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = nil
    }

    func setHandler(_ handler: (@Sendable ([RemoteChangeRecord]) -> Void)?) {
        lock.lock()
        defer { lock.unlock() }
        self.handler = handler
        guard let handler, heldRecords.isEmpty == false else { return }
        let held = heldRecords
        heldRecords = []
        handler(held)
    }

    @discardableResult
    func process() throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        let context = container.newBackgroundContext()
        context.transactionAuthor = author.rawValue
        let harvest: Harvest
        do {
            harvest = try context.performAndWait {
                try readHistory(in: context)
            }
        } catch {
            throw CorbieError.persistence(error.localizedDescription)
        }
        if let token = harvest.token {
            store(token)
        }
        if harvest.merges.isEmpty == false {
            mergeIntoViewContext(harvest.merges)
            WidgetReloadRequest.post()
            RemoteChangesMerged.post()
            changes?.post(
                StoreChange(origin: .elsewhere, entityNames: Set(harvest.records.compactMap(\.entityName)))
            )
        }
        if harvest.records.isEmpty == false {
            if let handler {
                handler(harvest.records)
            } else if holdsRecordsUntilHandled {
                heldRecords.append(contentsOf: harvest.records)
            }
        }
        return harvest.merges.count
    }

    private func mergeIntoViewContext(_ merges: [[AnyHashable: Any]]) {
        let viewContext = container.viewContext
        let batch = ObjectIDChanges(changes: merges)
        viewContext.perform {
            for change in batch.changes {
                NSManagedObjectContext.mergeChanges(fromRemoteContextSave: change, into: [viewContext])
            }
        }
    }

    private struct ObjectIDChanges: @unchecked Sendable {
        let changes: [[AnyHashable: Any]]
    }

    private struct Harvest {
        var token: NSPersistentHistoryToken?
        var merges: [[AnyHashable: Any]] = []
        var records: [RemoteChangeRecord] = []
    }

    private func readHistory(in context: NSManagedObjectContext) throws -> Harvest {
        let request = NSPersistentHistoryChangeRequest.fetchHistory(after: storedToken)
        let result = try context.execute(request) as? NSPersistentHistoryResult
        let transactions = result?.result as? [NSPersistentHistoryTransaction] ?? []
        var harvest = Harvest()
        for transaction in transactions {
            harvest.token = transaction.token
            guard transaction.author != author.rawValue else { continue }
            harvest.merges.append(transaction.objectIDNotification().userInfo ?? [:])
            harvest.records.append(contentsOf: PersistentHistoryObserver.records(in: transaction))
        }
        let storeIdentifiers = container.persistentStoreCoordinator.persistentStores.compactMap(\.identifier)
        if let cutoff = cleanupCutoff?(storeIdentifiers) {
            _ = try context.execute(NSPersistentHistoryChangeRequest.deleteHistory(before: cutoff))
        }
        return harvest
    }

    private static func records(in transaction: NSPersistentHistoryTransaction) -> [RemoteChangeRecord] {
        (transaction.changes ?? []).map { change in
            RemoteChangeRecord(
                objectURI: change.changedObjectID.uriRepresentation(),
                entityName: change.changedObjectID.entity.name,
                type: changeType(change.changeType),
                properties: Set((change.updatedProperties ?? []).map(\.name)),
                author: transaction.author,
                contextName: transaction.contextName
            )
        }
    }

    private static func changeType(_ raw: NSPersistentHistoryChangeType) -> RemoteChangeType {
        switch raw {
        case .insert: return .insert
        case .update: return .update
        case .delete: return .delete
        @unknown default: return .update
        }
    }

    private func store(_ token: NSPersistentHistoryToken) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
            return
        }
        defaults.set(data, forKey: tokenKey)
    }
}
