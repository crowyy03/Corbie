import CoreData
import Foundation

public enum HistoryCleanupRule {
    public static let retention: TimeInterval = 7 * 24 * 60 * 60

    public static func cutoff(
        now: Date,
        storeIdentifiers: [String],
        lastUploadStarts: [String: Date],
        retention: TimeInterval = HistoryCleanupRule.retention
    ) -> Date? {
        guard storeIdentifiers.isEmpty == false else { return nil }
        var cutoff = now.addingTimeInterval(-retention)
        for identifier in storeIdentifiers {
            guard let uploadStart = lastUploadStarts[identifier] else { return nil }
            cutoff = min(cutoff, uploadStart)
        }
        return cutoff
    }
}

final class CloudKitExportLedger: @unchecked Sendable {
    typealias EventReader = @Sendable (Notification) -> CloudKitMirroringEvent?

    static let storageKey = "cloudkit.export.lastSucceededStart"

    private let lock = NSLock()
    private let defaults: UserDefaults
    private let center: NotificationCenter
    private var observer: (any NSObjectProtocol)?

    init(
        defaults: UserDefaults,
        center: NotificationCenter = .default,
        readEvent: @escaping EventReader = { CloudKitMirroringEvent(notification: $0) }
    ) {
        self.defaults = defaults
        self.center = center
        let token = center.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let event = readEvent(notification) else { return }
            self?.record(event)
        }
        lock.withLock { observer = token }
    }

    deinit {
        let token = lock.withLock { observer }
        if let token {
            center.removeObserver(token)
        }
    }

    var lastUploadStarts: [String: Date] {
        lock.withLock { storedStarts() }
    }

    func record(_ event: CloudKitMirroringEvent) {
        guard event.kind == .exporting, event.succeeded, event.endedAt != nil else { return }
        lock.withLock {
            var starts = storedStarts()
            if let known = starts[event.storeIdentifier], known >= event.startedAt { return }
            starts[event.storeIdentifier] = event.startedAt
            defaults.set(starts.mapValues(\.timeIntervalSince1970), forKey: CloudKitExportLedger.storageKey)
        }
    }

    private func storedStarts() -> [String: Date] {
        let raw = defaults.dictionary(forKey: CloudKitExportLedger.storageKey) as? [String: TimeInterval] ?? [:]
        return raw.mapValues(Date.init(timeIntervalSince1970:))
    }
}
