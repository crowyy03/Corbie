import Foundation

public enum NotificationCategories {
    public static let task = "CORBIE_TASK"
    public static let vote = "CORBIE_VOTE"

    public enum Action {
        public static let takeTask = "CORBIE_TASK_TAKE"
        public static let completeTask = "CORBIE_TASK_DONE"
        public static let castVote = "CORBIE_VOTE_CAST"
    }

    public static let taskCategory = NotificationCategoryDescriptor(
        identifier: task,
        actions: [
            NotificationActionDescriptor(
                identifier: Action.takeTask,
                titleKey: "notification.action.task.take",
                opensApp: false
            ),
            NotificationActionDescriptor(
                identifier: Action.completeTask,
                titleKey: "notification.action.task.done",
                opensApp: false
            )
        ]
    )

    public static let voteCategory = NotificationCategoryDescriptor(
        identifier: vote,
        actions: [
            NotificationActionDescriptor(
                identifier: Action.castVote,
                titleKey: "notification.action.vote.cast",
                opensApp: true
            )
        ]
    )

    public static let all: [NotificationCategoryDescriptor] = [taskCategory, voteCategory]
}

public enum CorbieRoute: Sendable, Equatable, Hashable {
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

    public static func remoteKind(from userInfo: [String: Any]) -> RemoteChangeKind? {
        guard let raw = userInfo[kindKey] as? String else { return nil }
        return RemoteChangeKind(rawValue: raw)
    }
}

public enum NotificationStrings {
    public static let eventReminderTitle = "notification.event.reminder.title"
    public static let eventReminderBody = "notification.event.reminder.body"
    public static let eventTodayTitle = "notification.event.today.title"
    public static let eventTodayBody = "notification.event.today.body"
    public static let eventTomorrowTitle = "notification.event.tomorrow.title"
    public static let eventTomorrowBody = "notification.event.tomorrow.body"
    public static let taskDueTodayTitle = "notification.task.duetoday.title"
    public static let taskDueTodayBody = "notification.task.duetoday.body"
    public static let capsuleReceivedTitle = "notification.capsule.received.title"
    public static let capsuleReceivedBody = "notification.capsule.received.body"
    public static let capsuleSentTitle = "notification.capsule.sent.title"
    public static let capsuleSentBody = "notification.capsule.sent.body"
    public static let radarTitle = "notification.radar.title"
    public static let radarBodyPicked = "notification.radar.body.picked"
    public static let radarBodyMissing = "notification.radar.body.missing"
    public static let taskAssignedTitle = "notification.task.assigned.title"
    public static let taskAssignedBody = "notification.task.assigned.body"
    public static let taskTakenTitle = "notification.task.taken.title"
    public static let taskTakenBody = "notification.task.taken.body"
    public static let taskHandedBackTitle = "notification.task.handedback.title"
    public static let taskHandedBackBody = "notification.task.handedback.body"
    public static let wishAddedTitle = "notification.wish.added.title"
    public static let wishAddedBody = "notification.wish.added.body"
    public static let planExpenseTitle = "notification.plan.expense.title"
    public static let planExpenseBody = "notification.plan.expense.body"
    public static let planGoalTitle = "notification.plan.goal.title"
    public static let planGoalBody = "notification.plan.goal.body"
    public static let planOverTitle = "notification.plan.over.title"
    public static let planOverBody = "notification.plan.over.body"
    public static let capsuleOpenedTitle = "notification.capsule.opened.title"
    public static let capsuleOpenedBody = "notification.capsule.opened.body"
    public static let voteNewTitle = "notification.vote.new.title"
    public static let voteNewBody = "notification.vote.new.body"
    public static let voteRevealedTitle = "notification.vote.revealed.title"
    public static let voteRevealedBody = "notification.vote.revealed.body"

    public static let all: [String] = [
        eventReminderTitle,
        eventReminderBody,
        eventTodayTitle,
        eventTodayBody,
        eventTomorrowTitle,
        eventTomorrowBody,
        taskDueTodayTitle,
        taskDueTodayBody,
        capsuleReceivedTitle,
        capsuleReceivedBody,
        capsuleSentTitle,
        capsuleSentBody,
        radarTitle,
        radarBodyPicked,
        radarBodyMissing,
        taskAssignedTitle,
        taskAssignedBody,
        taskTakenTitle,
        taskTakenBody,
        taskHandedBackTitle,
        taskHandedBackBody,
        wishAddedTitle,
        wishAddedBody,
        planExpenseTitle,
        planExpenseBody,
        planGoalTitle,
        planGoalBody,
        planOverTitle,
        planOverBody,
        capsuleOpenedTitle,
        capsuleOpenedBody,
        voteNewTitle,
        voteNewBody,
        voteRevealedTitle,
        voteRevealedBody,
        "notification.action.task.take",
        "notification.action.task.done",
        "notification.action.vote.cast"
    ]
}
