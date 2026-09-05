import Foundation

public enum NotificationAuthorization: String, Sendable, Equatable, CaseIterable {
    case notDetermined
    case denied
    case authorized
    case provisional
}

public struct NotificationActionDescriptor: Sendable, Equatable {
    public let identifier: String
    public let titleKey: String
    public let opensApp: Bool

    public init(identifier: String, titleKey: String, opensApp: Bool) {
        self.identifier = identifier
        self.titleKey = titleKey
        self.opensApp = opensApp
    }
}

public struct NotificationCategoryDescriptor: Sendable, Equatable {
    public let identifier: String
    public let actions: [NotificationActionDescriptor]

    public init(identifier: String, actions: [NotificationActionDescriptor]) {
        self.identifier = identifier
        self.actions = actions
    }
}

public struct CorbieNotificationContent: Sendable, Equatable {
    public var titleKey: String
    public var bodyKey: String
    public var arguments: [String]
    public var categoryIdentifier: String?
    public var threadIdentifier: String?
    public var userInfo: [String: String]

    public init(
        titleKey: String,
        bodyKey: String,
        arguments: [String] = [],
        categoryIdentifier: String? = nil,
        threadIdentifier: String? = nil,
        userInfo: [String: String] = [:]
    ) {
        self.titleKey = titleKey
        self.bodyKey = bodyKey
        self.arguments = arguments
        self.categoryIdentifier = categoryIdentifier
        self.threadIdentifier = threadIdentifier
        self.userInfo = userInfo
    }
}

public struct CorbieNotificationRequest: Sendable, Equatable, Identifiable {
    public let id: String
    public let fireDate: Date
    public let content: CorbieNotificationContent

    public init(id: String, fireDate: Date, content: CorbieNotificationContent) {
        self.id = id
        self.fireDate = fireDate
        self.content = content
    }
}

public protocol NotificationCenterClient: Sendable {
    func authorizationStatus() async -> NotificationAuthorization
    func requestAuthorization() async throws -> Bool
    func registerCategories(_ categories: [NotificationCategoryDescriptor]) async
    func pendingIdentifiers() async -> [String]
    func add(_ request: CorbieNotificationRequest) async throws
    func removePending(identifiers: [String]) async
}

public enum NotificationText {
    public static func resolve(_ key: String, arguments: [String], locale: Locale = .current) -> String {
        let format = String(localized: String.LocalizationValue(key))
        guard arguments.isEmpty == false else { return format }
        return String(format: format, locale: locale, arguments: arguments)
    }

    public static func resolve(_ content: CorbieNotificationContent, locale: Locale = .current) -> (title: String, body: String) {
        (
            title: resolve(content.titleKey, arguments: content.arguments, locale: locale),
            body: resolve(content.bodyKey, arguments: content.arguments, locale: locale)
        )
    }
}

#if canImport(UserNotifications)
import UserNotifications

public struct SystemNotificationCenterClient: NotificationCenterClient {
    private let calendar: Calendar
    private let locale: Locale

    public init(calendar: Calendar = .current, locale: Locale = .current) {
        self.calendar = calendar
        self.locale = locale
    }

    public func authorizationStatus() async -> NotificationAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .ephemeral:
            return .authorized
        case .provisional:
            return .provisional
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }

    public func requestAuthorization() async throws -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            throw CorbieError.auth(error.localizedDescription)
        }
    }

    public func registerCategories(_ categories: [NotificationCategoryDescriptor]) async {
        let mapped = categories.map { descriptor in
            UNNotificationCategory(
                identifier: descriptor.identifier,
                actions: descriptor.actions.map { action in
                    UNNotificationAction(
                        identifier: action.identifier,
                        title: NotificationText.resolve(action.titleKey, arguments: [], locale: locale),
                        options: action.opensApp ? [.foreground] : []
                    )
                },
                intentIdentifiers: [],
                options: []
            )
        }
        UNUserNotificationCenter.current().setNotificationCategories(Set(mapped))
    }

    public func pendingIdentifiers() async -> [String] {
        await UNUserNotificationCenter.current().pendingNotificationRequests().map(\.identifier)
    }

    public func add(_ request: CorbieNotificationRequest) async throws {
        let text = NotificationText.resolve(request.content, locale: locale)
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        content.sound = .default
        if let categoryIdentifier = request.content.categoryIdentifier {
            content.categoryIdentifier = categoryIdentifier
        }
        if let threadIdentifier = request.content.threadIdentifier {
            content.threadIdentifier = threadIdentifier
        }
        content.userInfo = request.content.userInfo
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: request.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        do {
            try await UNUserNotificationCenter.current().add(
                UNNotificationRequest(identifier: request.id, content: content, trigger: trigger)
            )
        } catch {
            throw CorbieError.persistence(error.localizedDescription)
        }
    }

    public func removePending(identifiers: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
#endif
