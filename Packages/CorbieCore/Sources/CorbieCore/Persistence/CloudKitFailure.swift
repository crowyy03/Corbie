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

    public init(step: String, reason: Reason, detail: String) {
        self.step = step
        self.reason = reason
        self.detail = detail
    }

    public init(step: String, error: any Error) {
        self.init(
            step: step,
            reason: CloudKitFailure.reason(for: error),
            detail: CloudKitFailure.detail(for: error)
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
        case .unknownItem, .zoneNotFound, .userDeletedZone, .assetFileNotFound:
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

    private static func detail(for error: any Error) -> String {
        guard let error = error as? CKError else { return error.localizedDescription }
        return "CKError \(error.errorCode) \(error.localizedDescription)"
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
