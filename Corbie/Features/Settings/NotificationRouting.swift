import CorbieCore
import Foundation
import UserNotifications

struct NotificationResponse: Sendable, Equatable {
    let actionIdentifier: String
    let route: CorbieRoute?
    let objectId: UUID?

    init(actionIdentifier: String, route: CorbieRoute?, objectId: UUID? = nil) {
        self.actionIdentifier = actionIdentifier
        self.route = route
        self.objectId = objectId
    }

    init(actionIdentifier: String, userInfo: [AnyHashable: Any]) {
        var payload: [String: Any] = [:]
        for (key, value) in userInfo {
            guard let key = key as? String else { continue }
            payload[key] = value
        }
        self.init(
            actionIdentifier: actionIdentifier,
            route: NotificationPayload.route(from: payload),
            objectId: NotificationPayload.objectId(from: payload)
        )
    }

    var taskId: UUID? {
        if case let .task(id) = route { return id }
        return objectId
    }
}

enum NotificationOutcome: Equatable {
    case takeTask(UUID)
    case completeTask(UUID)
    case open(Route)
    case ignored
}

enum NotificationRouting {
    static func outcome(for response: NotificationResponse) -> NotificationOutcome {
        switch response.actionIdentifier {
        case NotificationCategories.Action.takeTask:
            guard let taskId = response.taskId else { return .ignored }
            return .takeTask(taskId)
        case NotificationCategories.Action.completeTask:
            guard let taskId = response.taskId else { return .ignored }
            return .completeTask(taskId)
        case UNNotificationDismissActionIdentifier:
            return .ignored
        default:
            guard let route = response.route, let destination = Router.route(for: route) else { return .ignored }
            return .open(destination)
        }
    }
}
