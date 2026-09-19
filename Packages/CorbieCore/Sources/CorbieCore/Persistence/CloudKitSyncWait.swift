import CoreData
import Foundation

public enum CloudKitSyncOutcome: Sendable, Equatable {
    case finished
    case failed(String)
    case timedOut
}

final class CloudKitSyncWait: @unchecked Sendable {
    typealias EventReader = @Sendable (Notification) -> CloudKitMirroringEvent?

    private let lock = NSLock()
    private let center: NotificationCenter
    private var observer: (any NSObjectProtocol)?
    private var result: CloudKitSyncOutcome?
    private var waiter: CheckedContinuation<CloudKitSyncOutcome, Never>?

    init(
        kind: CloudKitMirroringEvent.Kind,
        storeIdentifier: String?,
        startedAtOrAfter marker: Date,
        center: NotificationCenter = .default,
        readEvent: @escaping EventReader = { CloudKitMirroringEvent(notification: $0) }
    ) {
        self.center = center
        let token = center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let event = readEvent(notification),
                  event.isFinished(kind, of: storeIdentifier, startedAtOrAfter: marker)
            else { return }
            self?.finish(event.succeeded ? .finished : .failed(event.failure ?? "sync failed"))
        }
        lock.withLock { observer = token }
    }

    deinit {
        stopObserving()
    }

    func outcome(within timeout: Duration) async -> CloudKitSyncOutcome {
        let timer = Task { [weak self] in
            guard (try? await Task.sleep(for: timeout)) != nil else { return }
            self?.finish(.timedOut)
        }
        defer { timer.cancel() }
        return await withCheckedContinuation { continuation in
            let settled: CloudKitSyncOutcome? = lock.withLock {
                if let result { return result }
                waiter = continuation
                return nil
            }
            if let settled {
                continuation.resume(returning: settled)
            }
        }
    }

    private func finish(_ outcome: CloudKitSyncOutcome) {
        var isFirst = false
        var waiting: CheckedContinuation<CloudKitSyncOutcome, Never>?
        lock.withLock {
            guard result == nil else { return }
            isFirst = true
            result = outcome
            waiting = waiter
            waiter = nil
        }
        guard isFirst else { return }
        stopObserving()
        waiting?.resume(returning: outcome)
    }

    private func stopObserving() {
        let token: (any NSObjectProtocol)? = lock.withLock {
            defer { observer = nil }
            return observer
        }
        if let token {
            center.removeObserver(token)
        }
    }
}

public struct CloudKitUploadWatch: Sendable {
    private let wait: CloudKitSyncWait?

    init(wait: CloudKitSyncWait?) {
        self.wait = wait
    }

    public func finished(within timeout: Duration) async -> Bool {
        guard let wait else { return false }
        return await wait.outcome(within: timeout) == .finished
    }
}

