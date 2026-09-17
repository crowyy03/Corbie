import CloudKit
import Foundation
import os

public enum RemotePushOutcome: String, Sendable, Equatable {
    case newData
    case noData
    case failed
}

public final class RemotePushSync: @unchecked Sendable {
    public static let importTimeout: Duration = .seconds(20)
    public static let budget: Duration = .seconds(25)

    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "remote-push")

    private let stack: CoreDataStack
    private let notifier: RemoteChangeNotifier
    private let scope: StoreScope?
    private let arrivedAt: Date
    private let importWait: CloudKitSyncWait?
    private let center: NotificationCenter
    private let lock = NSLock()
    private var mergeObserver: (any NSObjectProtocol)?
    private var mergedBatches = 0

    public init(
        stack: CoreDataStack,
        notifier: RemoteChangeNotifier,
        scope: StoreScope?,
        arrivedAt: Date = Date(),
        center: NotificationCenter = .default
    ) {
        self.stack = stack
        self.notifier = notifier
        self.scope = scope
        self.arrivedAt = arrivedAt
        self.center = center
        importWait = stack.importWait(for: scope, arrivedAt: arrivedAt)
        let token = center.addObserver(
            forName: RemoteChangesMerged.notificationName,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.countMerge()
        }
        lock.withLock { mergeObserver = token }
    }

    deinit {
        if let mergeObserver {
            center.removeObserver(mergeObserver)
        }
    }

    public static func scope(ofPush userInfo: [AnyHashable: Any]) -> StoreScope? {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKDatabaseNotification
        else { return nil }
        switch notification.databaseScope {
        case .private: return .privateStore
        case .shared: return .sharedStore
        default: return nil
        }
    }

    public var progress: RemotePushOutcome {
        lock.withLock { mergedBatches } > 0 ? .newData : .noData
    }

    public func finish() async -> RemotePushOutcome {
        let imported = await importWait?.outcome(within: RemotePushSync.importTimeout)
        do {
            try stack.processHistory()
        } catch {
            RemotePushSync.log.error("history after a push failed: \(error.localizedDescription, privacy: .public)")
        }
        await notifier.waitForPendingChanges()
        let outcome: RemotePushOutcome
        if case .failed? = imported, progress == .noData {
            outcome = .failed
        } else {
            outcome = progress
        }
        let store = scope?.rawValue ?? "unknown"
        let importResult = imported.map { String(describing: $0) } ?? "not awaited"
        let seconds = Date().timeIntervalSince(arrivedAt)
        RemotePushSync.log.notice(
            "push for the \(store, privacy: .public) store: import \(importResult, privacy: .public), \(outcome.rawValue, privacy: .public) after \(seconds, privacy: .public) s"
        )
        return outcome
    }

    private func countMerge() {
        lock.withLock { mergedBatches += 1 }
    }
}
