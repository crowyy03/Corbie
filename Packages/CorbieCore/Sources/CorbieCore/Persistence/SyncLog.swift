import CoreData
import Foundation
import os

struct SyncLogEntry: Sendable, Equatable {
    enum Level: Sendable, Equatable {
        case notice
        case error
    }

    let level: Level
    let text: String

    static func notice(_ text: String) -> SyncLogEntry { SyncLogEntry(level: .notice, text: text) }
    static func error(_ text: String) -> SyncLogEntry { SyncLogEntry(level: .error, text: text) }
}

enum SyncLog {
    static let logger = Logger(subsystem: CorbieIdentifiers.bundleID, category: "sync")
    static let unknown = "unknown"
    static let recordFailureLimit = 20

    static func write(_ entry: SyncLogEntry) {
        switch entry.level {
        case .notice: logger.notice("\(entry.text, privacy: .public)")
        case .error: logger.error("\(entry.text, privacy: .public)")
        }
    }

    static func changeLines(
        _ direction: SyncDirection,
        store: String,
        changes: [SyncedChange],
        zones: [NSManagedObjectID: String]
    ) -> [SyncLogEntry] {
        guard changes.isEmpty == false else {
            return [.notice("\(direction.rawValue) ok store=\(store) no model changes")]
        }
        var counts: [ChangeGroup: ChangeCounts] = [:]
        for change in changes {
            let group = ChangeGroup(zone: zones[change.objectID] ?? unknown, entity: change.entityName)
            counts[group, default: ChangeCounts()].add(change.type)
        }
        return counts.keys.sorted().map { group in
            let count = counts[group] ?? ChangeCounts()
            return .notice(
                "\(direction.rawValue) ok store=\(store) zone=\(group.zone) \(group.entity) "
                    + "+\(count.inserts) ~\(count.updates) -\(count.deletes)"
            )
        }
    }

    static func failureLines(
        _ operation: String,
        store: String,
        report: CloudKitErrorReport?,
        limit: Int = recordFailureLimit
    ) -> [SyncLogEntry] {
        let prefix = "\(operation) failed store=\(store)"
        guard let report else { return [.error("\(prefix) domain=\(unknown) code=0")] }
        var headline = "\(prefix) domain=\(report.domain) code=\(report.code)"
        if let underlyingDomain = report.underlyingDomain, let underlyingCode = report.underlyingCode {
            headline += " underlying=\(underlyingDomain)/\(underlyingCode)"
        }
        var lines: [SyncLogEntry] = [.error(headline)]
        for record in report.records.prefix(limit) {
            lines.append(.error(
                "\(prefix) record=\(record.recordName ?? unknown) zone=\(record.zoneName ?? unknown) code=\(record.code)"
            ))
        }
        let dropped = report.records.count - limit
        if dropped > 0 {
            lines.append(.error("\(prefix) dropped \(dropped) more record errors"))
        }
        return lines
    }

    static func zonesLine(store: String, spaces: [String], shares: [String]) -> SyncLogEntry {
        .notice("zones store=\(store) spaces=\(list(spaces)) shares=\(list(shares))")
    }

    static func purgeAskedLine(store: String, zone: String, reason: ZonePurgeReason) -> SyncLogEntry {
        .notice("purge asked store=\(store) zone=\(zone) reason=\(reason.rawValue)")
    }

    static func purgeResultLine(
        store: String,
        zone: String,
        reason: ZonePurgeReason,
        error: (any Error)?,
        zoneWasMissing: Bool
    ) -> SyncLogEntry {
        let subject = "store=\(store) zone=\(zone) reason=\(reason.rawValue)"
        guard let error else { return .notice("purge ok \(subject)") }
        let failure = error as NSError
        let detail = "domain=\(failure.domain) code=\(failure.code)"
        if zoneWasMissing {
            return .notice("purge missing \(subject) \(detail)")
        }
        return .error("purge failed \(subject) \(detail)")
    }

    private static func list(_ zones: [String]) -> String {
        let unique = Array(Set(zones)).sorted()
        return unique.isEmpty ? "none" : unique.joined(separator: ",")
    }

    private struct ChangeGroup: Hashable, Comparable {
        let zone: String
        let entity: String

        static func < (lhs: ChangeGroup, rhs: ChangeGroup) -> Bool {
            (lhs.zone, lhs.entity) < (rhs.zone, rhs.entity)
        }
    }

    private struct ChangeCounts {
        var inserts = 0
        var updates = 0
        var deletes = 0

        mutating func add(_ type: RemoteChangeType) {
            switch type {
            case .insert: inserts += 1
            case .update: updates += 1
            case .delete: deletes += 1
            }
        }
    }
}

enum SyncDirection: String, Sendable, CaseIterable {
    case exporting = "export"
    case importing = "import"

    static let importAuthor = "NSCloudKitMirroringDelegate.import"
    static let mirroringAuthorPrefix = "NSCloudKitMirroringDelegate."

    init?(_ kind: CloudKitMirroringEvent.Kind) {
        switch kind {
        case .exporting: self = .exporting
        case .importing: self = .importing
        case .setup, .unknown: return nil
        }
    }

    func carries(author: String?) -> Bool {
        switch self {
        case .importing:
            return author == SyncDirection.importAuthor
        case .exporting:
            return author?.hasPrefix(SyncDirection.mirroringAuthorPrefix) != true
        }
    }
}

struct SyncedChange: Sendable, Equatable {
    let objectID: NSManagedObjectID
    let entityName: String
    let type: RemoteChangeType
}

enum ZonePurgeReason: String, Sendable {
    case leave
    case deleteAccount
}
