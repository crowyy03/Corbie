import CorbieCore
import Foundation

enum Route: Equatable {
    case today
    case tasks
    case task(UUID)
    case calendar
    case wishes
    case plans
    case plan(UUID)
    case lists
    case list(UUID)
    case capsules
    case votes
    case people
    case person(UUID)
    case us
    case join(String)
    case paywall
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

    static func route(for route: CorbieRoute) -> Route {
        switch route {
        case .today: return .today
        case .tasks: return .tasks
        case let .task(id): return .task(id)
        case .calendar: return .calendar
        case .event: return .calendar
        case .wishes, .wish: return .wishes
        case .plans: return .plans
        case let .plan(id): return .plan(id)
        case .lists: return .lists
        case let .list(id): return .list(id)
        case .capsules, .capsule: return .capsules
        case .votes, .vote: return .votes
        case .people: return .people
        case let .person(id): return .person(id)
        case .us: return .us
        case .paywall: return .paywall
        }
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
        case "today":
            return .today
        case "tasks":
            return identified(rest.first, make: Route.task) ?? .tasks
        case "calendar":
            return .calendar
        case "wishes":
            return .wishes
        case CorbieRoute.Segment.plans:
            guard let identifier = rest.first else { return .plans }
            guard let planID = UUID(uuidString: identifier) else { return nil }
            return .plan(planID)
        case CorbieRoute.Segment.lists:
            guard let identifier = rest.first else { return .lists }
            guard let listID = UUID(uuidString: identifier) else { return nil }
            return .list(listID)
        case "capsules":
            return .capsules
        case "votes":
            return .votes
        case "people":
            return identified(rest.first, make: Route.person) ?? .people
        case "us":
            return .us
        case CorbieRoute.Segment.paywall:
            return .paywall
        case "join":
            return joinRoute(code: rest.first)
        default:
            return nil
        }
    }

    private static func identified(_ segment: String?, make: (UUID) -> Route) -> Route? {
        guard let segment, let identifier = UUID(uuidString: segment) else { return nil }
        return make(identifier)
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
