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

    init(container: NSPersistentContainer, author: TransactionAuthor, defaults: UserDefaults? = nil) {
        self.container = container
        self.author = author
        self.defaults = defaults ?? UserDefaults(suiteName: CorbieIdentifiers.appGroup) ?? .standard
    }

    var tokenKey: String { "history.token." + author.rawValue }

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

    @discardableResult
    func process() throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        let context = container.newBackgroundContext()
        context.transactionAuthor = author.rawValue
        let token: NSPersistentHistoryToken?
        let changes: [[AnyHashable: Any]]
        do {
            (token, changes) = try context.performAndWait {
                try readHistory(in: context)
            }
        } catch {
            throw CorbieError.persistence(error.localizedDescription)
        }
        for change in changes {
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: change, into: [container.viewContext])
        }
        if let token {
            store(token)
        }
        if changes.isEmpty == false {
            WidgetReloadRequest.post()
        }
        return changes.count
    }

    private func readHistory(
        in context: NSManagedObjectContext
    ) throws -> (NSPersistentHistoryToken?, [[AnyHashable: Any]]) {
        let request = NSPersistentHistoryChangeRequest.fetchHistory(after: storedToken)
        let result = try context.execute(request) as? NSPersistentHistoryResult
        let transactions = result?.result as? [NSPersistentHistoryTransaction] ?? []
        var token: NSPersistentHistoryToken?
        var changes: [[AnyHashable: Any]] = []
        for transaction in transactions {
            token = transaction.token
            guard transaction.author != author.rawValue else { continue }
            changes.append(transaction.objectIDNotification().userInfo ?? [:])
        }
        let cutoff = Date().addingTimeInterval(-PersistentHistoryObserver.retention)
        _ = try context.execute(NSPersistentHistoryChangeRequest.deleteHistory(before: cutoff))
        return (token, changes)
    }

    private func store(_ token: NSPersistentHistoryToken) {
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
            return
        }
        defaults.set(data, forKey: tokenKey)
    }
}
