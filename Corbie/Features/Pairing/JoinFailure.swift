import CorbieCore
import Foundation

enum JoinFailure: String, Equatable, CaseIterable {
    case notFound
    case expired
    case redeemed
    case throttled
    case iCloud
    case generic

    static func kind(for error: any Error) -> JoinFailure {
        if let api = error as? APIError {
            if api.isNotFound { return .notFound }
            if api.isExpired { return .expired }
            if api.isRedeemed { return .redeemed }
            if api.isRateLimited { return .throttled }
        }
        if let corbie = error as? CorbieError, case .cloudKit = corbie { return .iCloud }
        return .generic
    }

    var message: String {
        switch self {
        case .notFound: return String(localized: "pairing.join.error.notfound")
        case .expired: return String(localized: "pairing.join.error.expired")
        case .redeemed: return String(localized: "pairing.join.error.redeemed")
        case .throttled: return String(localized: "pairing.join.error.throttled")
        case .iCloud: return String(localized: "pairing.join.error.icloud")
        case .generic: return String(localized: "pairing.join.error.generic")
        }
    }
}
