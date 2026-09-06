import CoreData
import Foundation
import os

final class PersistentHistoryObserver: @unchecked Sendable {
    static let retention: TimeInterval = 7 * 24 * 60 * 60

    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "history")

    private let container: NSPersistentContainer
    private let author: TransactionAuthor
    private let defaults: UserDefaults
    private let lock = NSLock()
    private var observer: (any NSObjectProtocol)?
    private var handler: (@Sendable ([RemoteChangeRecord]) -> Void)?

    init(container: NSPersistentContainer, author: TransactionAuthor, defaults: UserDefaults = .corbieShared) {
        self.container = container
        self.author = author
        self.defaults = defaults
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
    }

    @discardableResult
    func process() throws -> Int {
        lock.lock()
        let currentHandler = handler
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
        for change in harvest.merges {
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: change, into: [container.viewContext])
        }
        if let token = harvest.token {
            store(token)
        }
        if harvest.merges.isEmpty == false {
            WidgetReloadRequest.post()
        }
        if harvest.records.isEmpty == false {
            currentHandler?(harvest.records)
        }
        return harvest.merges.count
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
        let cutoff = Date().addingTimeInterval(-PersistentHistoryObserver.retention)
        _ = try context.execute(NSPersistentHistoryChangeRequest.deleteHistory(before: cutoff))
        return harvest
    }

    private static func records(in transaction: NSPersistentHistoryTransaction) -> [RemoteChangeRecord] {
        (transaction.changes ?? []).compactMap { change in
            guard let entityName = change.changedObjectID.entity.name else { return nil }
            return RemoteChangeRecord(
                entityName: entityName,
                objectURI: change.changedObjectID.uriRepresentation(),
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
