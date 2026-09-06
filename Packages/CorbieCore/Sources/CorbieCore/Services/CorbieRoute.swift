import Foundation

public enum CorbieRoute: Sendable, Equatable, Hashable {
    case today
    case tasks
    case task(UUID)
    case calendar
    case event(UUID)
    case wishes
    case wish(UUID)
    case plans
    case plan(UUID)
    case lists
    case list(UUID)
    case capsules
    case capsule(UUID)
    case votes
    case vote(UUID)
    case people
    case person(UUID)
    case us
    case paywall

    public enum Segment {
        public static let today = "today"
        public static let tasks = "tasks"
        public static let calendar = "calendar"
        public static let events = "events"
        public static let wishes = "wishes"
        public static let plans = "plans"
        public static let lists = "lists"
        public static let capsules = "capsules"
        public static let votes = "votes"
        public static let people = "people"
        public static let us = "us"
        public static let paywall = "paywall"
    }

    public var path: String {
        switch self {
        case .today: return Segment.today
        case .tasks: return Segment.tasks
        case let .task(id): return Segment.tasks + "/" + id.uuidString
        case .calendar: return Segment.calendar
        case let .event(id): return Segment.events + "/" + id.uuidString
        case .wishes: return Segment.wishes
        case let .wish(id): return Segment.wishes + "/" + id.uuidString
        case .plans: return Segment.plans
        case let .plan(id): return Segment.plans + "/" + id.uuidString
        case .lists: return Segment.lists
        case let .list(id): return Segment.lists + "/" + id.uuidString
        case .capsules: return Segment.capsules
        case let .capsule(id): return Segment.capsules + "/" + id.uuidString
        case .votes: return Segment.votes
        case let .vote(id): return Segment.votes + "/" + id.uuidString
        case .people: return Segment.people
        case let .person(id): return Segment.people + "/" + id.uuidString
        case .us: return Segment.us
        case .paywall: return Segment.paywall
        }
    }

    public var urlString: String { CorbieRoute.scheme + path }

    public var url: URL? { URL(string: urlString) }

    public static let scheme = CorbieIdentifiers.urlScheme + "://"

    public init?(urlString: String) {
        guard urlString.hasPrefix(CorbieRoute.scheme) else { return nil }
        let parts = urlString
            .dropFirst(CorbieRoute.scheme.count)
            .split(separator: "/")
            .map(String.init)
        guard let head = parts.first else { return nil }
        let identifier = parts.count > 1 ? UUID(uuidString: parts[1]) : nil
        switch head {
        case Segment.today:
            self = .today
        case Segment.tasks:
            self = identifier.map(CorbieRoute.task) ?? .tasks
        case Segment.calendar:
            self = .calendar
        case Segment.events:
            guard let identifier else { return nil }
            self = .event(identifier)
        case Segment.wishes:
            self = identifier.map(CorbieRoute.wish) ?? .wishes
        case Segment.plans:
            self = identifier.map(CorbieRoute.plan) ?? .plans
        case Segment.lists:
            self = identifier.map(CorbieRoute.list) ?? .lists
        case Segment.capsules:
            self = identifier.map(CorbieRoute.capsule) ?? .capsules
        case Segment.votes:
            self = identifier.map(CorbieRoute.vote) ?? .votes
        case Segment.people:
            self = identifier.map(CorbieRoute.person) ?? .people
        case Segment.us:
            self = .us
        case Segment.paywall:
            self = .paywall
        default:
            return nil
        }
    }

    public init?(url: URL) {
        self.init(urlString: url.absoluteString)
    }
}

public enum NotificationPayload {
    public static let routeKey = "corbie.route"
    public static let kindKey = "corbie.kind"
    public static let objectKey = "corbie.object"

    public static func userInfo(
        kind: NotificationKind,
        route: CorbieRoute,
        objectId: UUID? = nil
    ) -> [String: String] {
        var info = [kindKey: kind.rawValue, routeKey: route.urlString]
        if let objectId {
            info[objectKey] = objectId.uuidString
        }
        return info
    }

    public static func userInfo(
        remote kind: RemoteChangeKind,
        route: CorbieRoute,
        objectId: UUID? = nil
    ) -> [String: String] {
        var info = [kindKey: kind.rawValue, routeKey: route.urlString]
        if let objectId {
            info[objectKey] = objectId.uuidString
        }
        return info
    }

    public static func route(from userInfo: [String: Any]) -> CorbieRoute? {
        guard let raw = userInfo[routeKey] as? String else { return nil }
        return CorbieRoute(urlString: raw)
    }

    public static func kind(from userInfo: [String: Any]) -> NotificationKind? {
        guard let raw = userInfo[kindKey] as? String else { return nil }
        return NotificationKind(rawValue: raw)
    }

    public static func objectId(from userInfo: [String: Any]) -> UUID? {
        guard let raw = userInfo[objectKey] as? String else { return nil }
        return UUID(uuidString: raw)
    }
}
