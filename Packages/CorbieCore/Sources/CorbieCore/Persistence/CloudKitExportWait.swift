import CoreData
import Foundation

public enum CloudKitExportOutcome: Sendable, Equatable {
    case exported
    case failed(String)
    case timedOut
}

final class CloudKitExportWait: @unchecked Sendable {
    typealias EventReader = @Sendable (Notification) -> CloudKitMirroringEvent?

    private let lock = NSLock()
    private let center: NotificationCenter
    private var observer: (any NSObjectProtocol)?
    private var result: CloudKitExportOutcome?
    private var waiter: CheckedContinuation<CloudKitExportOutcome, Never>?

    init(
        storeIdentifier: String,
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
                  event.isFinishedExport(of: storeIdentifier, startedAtOrAfter: marker)
            else { return }
            self?.finish(event.succeeded ? .exported : .failed(event.failure ?? "export failed"))
        }
        lock.withLock { observer = token }
    }

    deinit {
        stopObserving()
    }

    func outcome(within timeout: Duration) async -> CloudKitExportOutcome {
        let timer = Task { [weak self] in
            guard (try? await Task.sleep(for: timeout)) != nil else { return }
            self?.finish(.timedOut)
        }
        defer { timer.cancel() }
        return await withCheckedContinuation { continuation in
            let settled: CloudKitExportOutcome? = lock.withLock {
                if let result { return result }
                waiter = continuation
                return nil
            }
            if let settled {
                continuation.resume(returning: settled)
            }
        }
    }

    private func finish(_ outcome: CloudKitExportOutcome) {
        var isFirst = false
        var waiting: CheckedContinuation<CloudKitExportOutcome, Never>?
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
