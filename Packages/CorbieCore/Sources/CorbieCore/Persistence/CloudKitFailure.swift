import CloudKit
import Foundation

public struct CloudKitFailure: Error, Sendable, Equatable {
    public enum Reason: String, Sendable, Equatable, CaseIterable {
        case notSignedIn
        case accountBusy
        case network
        case missing
        case alreadyShared
        case quotaExceeded
        case other
    }

    public let step: String
    public let reason: Reason
    public let detail: String
    public let errorCode: Int?

    public init(step: String, reason: Reason, detail: String, errorCode: Int? = nil) {
        self.step = step
        self.reason = reason
        self.detail = detail
        self.errorCode = errorCode
    }

    public init(step: String, error: any Error) {
        self.init(
            step: step,
            reason: CloudKitFailure.reason(for: error),
            detail: CloudKitFailure.describe(error),
            errorCode: CloudKitFailure.itemCode(of: error)
        )
    }

    public static func reason(for error: any Error) -> Reason {
        guard let error = error as? CKError else { return .other }
        switch error.code {
        case .notAuthenticated, .managedAccountRestricted:
            return .notSignedIn
        case .accountTemporarilyUnavailable, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return .accountBusy
        case .networkUnavailable, .networkFailure:
            return .network
        case .unknownItem, .zoneNotFound, .userDeletedZone:
            return .missing
        case .alreadyShared:
            return .alreadyShared
        case .quotaExceeded:
            return .quotaExceeded
        case .partialFailure:
            let partials = (error.partialErrorsByItemID ?? [:]).values.map(reason(for:))
            return partials.first { $0 != .other } ?? .other
        default:
            return .other
        }
    }

    public static func itemCode(of error: any Error) -> Int? {
        guard let error = error as? CKError else { return nil }
        guard error.code == .partialFailure,
              let first = error.partialErrorsByItemID?.values.compactMap({ $0 as? CKError }).min(by: { $0.errorCode < $1.errorCode })
        else { return error.errorCode }
        return first.errorCode
    }

    public static func describe(_ error: any Error) -> String {
        let nsError = error as NSError
        let head = error is CKError ? "CKError" : nsError.domain
        var parts = ["\(head) \(nsError.code) \(error.localizedDescription)"]
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            parts.append("underlying \(underlying.domain) \(underlying.code) \(underlying.localizedDescription)")
        }
        let items = (error as? CKError)?.partialErrorsByItemID ?? [:]
        let named = items.map { (name: itemName($0.key), error: $0.value) }.sorted { $0.name < $1.name }
        for item in named {
            parts.append("item \(item.name): \(describe(item.error))")
        }
        return parts.joined(separator: "; ")
    }

    private static func itemName(_ item: AnyHashable) -> String {
        if let url = item.base as? URL { return ShareLinkLog.text(for: url) }
        if let recordID = item.base as? CKRecord.ID { return "\(recordID.zoneID.zoneName)/\(recordID.recordName)" }
        return String(describing: item.base)
    }
}

extension CloudKitFailure: LocalizedError {
    public var errorDescription: String? {
        String(localized: "error.cloudkit.message")
    }

    public var failureReason: String? {
        "\(step): \(reason.rawValue): \(detail)"
    }
}
