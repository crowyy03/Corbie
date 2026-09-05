import CorbieCore
import Foundation

enum Route: Equatable {
    case tasks
    case calendar
    case wishes
    case plans
    case plan(UUID)
    case capsules
    case votes
    case join(String)
}

enum Router {
    static func route(for url: URL) -> Route? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let scheme = components.scheme?.lowercased()
        let host = components.host?.lowercased()
        let path = components.path.split(separator: "/").map(String.init)

        if scheme == CorbieIdentifiers.urlScheme {
            guard let host else { return nil }
            return schemeRoute(segments: [host] + path)
        }

        if scheme == "https", isCorbieHost(host) {
            return webRoute(segments: path)
        }

        return nil
    }

    private static func isCorbieHost(_ host: String?) -> Bool {
        guard let host else { return false }
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return bare == CorbieIdentifiers.universalLinkHost
    }

    private static func schemeRoute(segments: [String]) -> Route? {
        guard let first = segments.first?.lowercased() else { return nil }
        let rest = segments.dropFirst()

        switch first {
        case "tasks":
            return .tasks
        case "calendar":
            return .calendar
        case "wishes":
            return .wishes
        case "plans":
            guard let identifier = rest.first else { return .plans }
            guard let planID = UUID(uuidString: identifier) else { return nil }
            return .plan(planID)
        case "capsules":
            return .capsules
        case "votes":
            return .votes
        case "join":
            return joinRoute(code: rest.first)
        default:
            return nil
        }
    }

    private static func webRoute(segments: [String]) -> Route? {
        guard segments.first?.lowercased() == "join" else { return nil }
        return joinRoute(code: segments.dropFirst().first)
    }

    private static func joinRoute(code: String?) -> Route? {
        guard let code, !code.isEmpty else { return nil }
        return .join(code.uppercased())
    }
}
