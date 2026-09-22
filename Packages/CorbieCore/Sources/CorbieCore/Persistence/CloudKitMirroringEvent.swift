import CoreData
import Foundation

public struct CloudKitMirroringEvent: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        case setup
        case importing
        case exporting
        case unknown
    }

    public let identifier: UUID
    public let kind: Kind
    public let storeIdentifier: String
    public let startedAt: Date
    public let endedAt: Date?
    public let succeeded: Bool
    public let failure: String?
    var errorReport: CloudKitErrorReport?

    public init(
        kind: Kind,
        storeIdentifier: String,
        startedAt: Date,
        endedAt: Date?,
        succeeded: Bool,
        failure: String? = nil,
        identifier: UUID = UUID()
    ) {
        self.identifier = identifier
        self.kind = kind
        self.storeIdentifier = storeIdentifier
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.succeeded = succeeded
        self.failure = failure
    }

    init?(notification: Notification) {
        let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
        guard let event = notification.userInfo?[key] as? NSPersistentCloudKitContainer.Event else { return nil }
        self.init(
            kind: Kind(event.type),
            storeIdentifier: event.storeIdentifier,
            startedAt: event.startDate,
            endedAt: event.endDate,
            succeeded: event.succeeded,
            failure: event.error?.localizedDescription,
            identifier: event.identifier
        )
        errorReport = event.error.map(CloudKitErrorReport.init)
    }

    func isFinished(_ kind: Kind, of storeIdentifier: String?, startedAtOrAfter marker: Date) -> Bool {
        guard self.kind == kind, endedAt != nil, startedAt >= marker else { return false }
        return storeIdentifier == nil || self.storeIdentifier == storeIdentifier
    }
}

private extension CloudKitMirroringEvent.Kind {
    init(_ type: NSPersistentCloudKitContainer.EventType) {
        switch type {
        case .setup: self = .setup
        case .import: self = .importing
        case .export: self = .exporting
        @unknown default: self = .unknown
        }
    }
}
