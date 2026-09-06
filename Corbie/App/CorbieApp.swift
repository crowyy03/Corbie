import CloudKit
import CorbieCore
import os
import SwiftUI
import UIKit
import UserNotifications

@main
struct CorbieApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @State private var environment: AppEnvironment

    init() {
        #if DEBUG
        DebugLaunch.resetStoreIfRequested()
        #endif
        _environment = State(initialValue: AppEnvironment())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(environment)
                .environment(environment.premiumGate)
                .environment(environment.toasts)
                .toastHost()
                .preferredColorScheme(environment.theme.preferredColorScheme)
                .task {
                    appDelegate.connect(environment: environment, appState: appState)
                    await environment.bootstrap()
                }
                .onOpenURL { url in
                    appState.open(Router.route(for: url))
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    appState.open(Router.route(for: url))
                }
        }
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    private let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "sharing")

    private var environment: AppEnvironment?
    private var appState: AppState?
    private var pending: [NotificationResponse] = []

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    func connect(environment: AppEnvironment, appState: AppState) {
        self.environment = environment
        self.appState = appState
        let queued = pending
        pending = []
        for response in queued {
            perform(response)
        }
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let stack = PersistenceController.shared.stack
        Task {
            let merged = (try? stack.processHistory()) ?? 0
            WidgetReloadRequest.post()
            completionHandler(merged > 0 ? .newData : .noData)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
        log.error("remote notifications are unavailable: \(error.localizedDescription, privacy: .public)")
    }

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        let sharing = CloudKitSharing(stack: PersistenceController.shared.stack)
        Task {
            do {
                try await sharing.acceptShare(metadata: cloudKitShareMetadata)
                WidgetReloadRequest.post()
            } catch {
                log.error("accepting the share failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func perform(_ response: NotificationResponse) {
        guard let environment, let appState else {
            pending.append(response)
            return
        }
        switch NotificationRouting.outcome(for: response) {
        case let .takeTask(taskId):
            write(environment) {
                try await TaskIntentRunner.take(taskId: taskId)
            }
        case let .completeTask(taskId):
            write(environment) {
                try await TaskIntentRunner.markDone(taskId: taskId)
                await environment.notifications.cancelTaskDueToday(taskId: taskId)
            }
        case let .open(route):
            appState.open(route)
        case .ignored:
            break
        }
    }

    private func write(_ environment: AppEnvironment, _ body: @escaping () async throws -> Void) {
        Task {
            do {
                try await body()
            } catch {
                environment.report(error)
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let parsed = NotificationResponse(
            actionIdentifier: response.actionIdentifier,
            userInfo: response.notification.request.content.userInfo
        )
        Task { @MainActor in
            perform(parsed)
            completionHandler()
        }
    }
}
