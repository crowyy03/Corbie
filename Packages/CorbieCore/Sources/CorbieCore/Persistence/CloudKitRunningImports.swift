import CoreData
import Foundation

final class CloudKitRunningImports: @unchecked Sendable {
    typealias EventReader = @Sendable (Notification) -> CloudKitMirroringEvent?

    private let lock = NSLock()
    private let center: NotificationCenter
    private var observer: (any NSObjectProtocol)?
    private var running: [UUID: CloudKitMirroringEvent] = [:]

    init(
        center: NotificationCenter = .default,
        readEvent: @escaping EventReader = { CloudKitMirroringEvent(notification: $0) }
    ) {
        self.center = center
        let token = center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let event = readEvent(notification), event.kind == .importing else { return }
            self?.record(event)
        }
        lock.withLock { observer = token }
    }

    deinit {
        if let observer {
            center.removeObserver(observer)
        }
    }

    func earliestStart(storeIdentifier: String?) -> Date? {
        lock.withLock {
            running.values
                .filter { storeIdentifier == nil || $0.storeIdentifier == storeIdentifier }
                .map(\.startedAt)
                .min()
        }
    }

    private func record(_ event: CloudKitMirroringEvent) {
        lock.withLock {
            if event.endedAt == nil {
                running[event.identifier] = event
            } else {
                running[event.identifier] = nil
            }
        }
    }
}
