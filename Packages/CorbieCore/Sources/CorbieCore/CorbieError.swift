import Foundation

public enum CorbieError: Error, Equatable, Sendable {
    case persistence(String)
    case cloudKit(String)
    case network(String)
    case auth(String)
    case notPremium
    case invalidInput(String)
    case notFound(String)
}

extension CorbieError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .persistence:
            return String(localized: "error.persistence.message")
        case .cloudKit:
            return String(localized: "error.cloudkit.message")
        case .network:
            return String(localized: "error.network.message")
        case .auth:
            return String(localized: "error.auth.message")
        case .notPremium:
            return String(localized: "error.notpremium.message")
        case .invalidInput:
            return String(localized: "error.invalidinput.message")
        case .notFound:
            return String(localized: "error.notfound.message")
        }
    }

    public var failureReason: String? {
        switch self {
        case let .persistence(detail), let .cloudKit(detail), let .network(detail),
             let .auth(detail), let .invalidInput(detail), let .notFound(detail):
            return detail
        case .notPremium:
            return nil
        }
    }
}
