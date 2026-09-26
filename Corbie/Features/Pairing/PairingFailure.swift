import CorbieCore
import Foundation

enum PairingFailure: String, Error, Equatable, CaseIterable {
    case notFound
    case expired
    case superseded
    case redeemed
    case throttled
    case signedOutOfICloud
    case iCloudBusy
    case iCloudFull
    case shareMissing
    case ownAccount
    case environmentMismatch
    case sharePending
    case spaceLate
    case signInAgain
    case serverMissing
    case network
    case iCloud
    case iCloudRefused
    case generic

    enum Side: Equatable {
        case inviting
        case joining
    }

    static func kind(for error: any Error, side: Side) -> PairingFailure {
        if let failure = error as? PairingFailure { return failure }
        if let failure = error as? CloudKitFailure {
            switch failure.reason {
            case .notSignedIn: return .signedOutOfICloud
            case .accountBusy: return .iCloudBusy
            case .quotaExceeded: return .iCloudFull
            case .network: return .network
            case .missing: return side == .joining ? .shareMissing : .iCloudRefused
            case .alreadyShared, .other: return .iCloudRefused
            }
        }
        if let api = error as? APIError {
            if api.isEnvironmentMismatch { return .environmentMismatch }
            if api.isSameICloudAccount { return .ownAccount }
            if api.isNotFound { return .notFound }
            if api.isSuperseded { return .superseded }
            if api.isExpired { return .expired }
            if api.isRedeemed { return .redeemed }
            if api.isRateLimited { return .throttled }
            if api.kind == .notConfigured { return .serverMissing }
            if api.isUnauthorized { return .signInAgain }
            if api.kind == .transport { return .network }
        }
        if let corbie = error as? CorbieError {
            switch corbie {
            case .cloudKit: return .iCloud
            case .auth: return .signInAgain
            case .notConfigured: return .serverMissing
            case .network: return .network
            default: return .generic
            }
        }
        return .generic
    }

    static func message(for error: any Error, side: Side) -> String {
        let kind = kind(for: error, side: side)
        guard kind == .iCloudRefused, let code = (error as? CloudKitFailure)?.errorCode else { return kind.message }
        return String(format: String(localized: "pairing.error.icloud.refused.code"), code)
    }

    var message: String {
        switch self {
        case .notFound: return String(localized: "pairing.join.error.notfound")
        case .expired: return String(localized: "pairing.join.error.expired")
        case .superseded: return String(localized: "pairing.join.error.superseded")
        case .redeemed: return String(localized: "pairing.join.error.redeemed")
        case .throttled: return String(localized: "pairing.join.error.throttled")
        case .signedOutOfICloud: return String(localized: "pairing.error.icloud.signedout")
        case .iCloudBusy: return String(localized: "pairing.error.icloud.busy")
        case .iCloudFull: return String(localized: "pairing.error.icloud.full")
        case .shareMissing: return String(localized: "pairing.error.share.missing")
        case .ownAccount: return String(localized: "pairing.error.icloud.ownaccount")
        case .environmentMismatch: return String(localized: "pairing.error.environment")
        case .sharePending: return String(localized: "pairing.error.share.pending")
        case .spaceLate: return String(localized: "pairing.error.space.late")
        case .signInAgain: return String(localized: "error.auth.message")
        case .serverMissing: return String(localized: "error.notconfigured.message")
        case .network: return String(localized: "error.network.message")
        case .iCloud: return String(localized: "pairing.join.error.icloud")
        case .iCloudRefused: return String(localized: "pairing.error.icloud.refused")
        case .generic: return String(localized: "pairing.join.error.generic")
        }
    }
}

extension PairingFailure: LocalizedError {
    var errorDescription: String? { message }

    var failureReason: String? { rawValue }
}
