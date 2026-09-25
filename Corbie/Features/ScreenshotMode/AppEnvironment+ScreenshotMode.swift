#if DEBUG
import CorbieCore
import Foundation

extension AppEnvironment {
    static func screenshotMode(
        _ session: ScreenshotModeSession,
        theme: ThemeProvider,
        intents: IntentPersistence,
        transport: (any HTTPTransport)? = nil
    ) -> AppEnvironment {
        AppEnvironment(
            persistence: session.controller,
            secrets: session.secrets,
            anonymousIdentity: .inMemory(),
            notificationClient: ScreenshotModeNotificationClient(),
            store: StoreService(),
            localEntitlements: ScreenshotModeLocalEntitlements(),
            transport: transport,
            defaults: session.defaults,
            analyticsDelivery: .discarded,
            analyticsStorage: InMemoryAnalyticsStorage(),
            theme: theme,
            intents: intents,
            storageProbe: { nil }
        )
    }

    var isScreenshotMode: Bool {
        persistence.screenshotModeSession != nil
    }
}

enum ScreenshotModeRefusal: LocalizedError, Equatable {
    case purchase
    case accountChange

    var errorDescription: String? {
        switch self {
        case .purchase: return "Screenshot mode never buys anything."
        case .accountChange: return "Screenshot mode never deletes the account or leaves the space."
        }
    }
}

struct ScreenshotModeLocalEntitlements: LocalEntitlementProviding {
    func subscriptions() async -> [StoreSubscription] { [] }
}

struct ScreenshotModeNotificationClient: NotificationCenterClient {
    func authorizationStatus() async -> NotificationAuthorization { .authorized }
    func requestAuthorization() async throws -> Bool { true }
    func registerCategories(_ categories: [NotificationCategoryDescriptor]) async {}
    func pendingIdentifiers() async -> [String] { [] }
    func add(_ request: CorbieNotificationRequest) async throws {}
    func removePending(identifiers: [String]) async {}
}
#endif
