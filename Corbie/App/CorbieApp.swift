import CloudKit
import CorbieCore
import os
import SwiftUI
import UIKit
import UserNotifications

@main
struct CorbieApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            root
                .onOpenURL { url in
                    appDelegate.appState.open(Router.route(for: url))
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    appDelegate.appState.open(Router.route(for: url))
                }
        }
    }

    @ViewBuilder private var root: some View {
        #if DEBUG
        ScreenshotModeRoot(screenshotMode: appDelegate.screenshotMode, appState: appDelegate.appState)
        #else
        ThemedRoot(appState: appDelegate.appState, environment: appDelegate.environment)
            .task {
                await appDelegate.environment.bootstrap()
            }
        #endif
    }
}

struct ThemedRoot: View {
    let appState: AppState
    let environment: AppEnvironment

    @Environment(\.colorScheme) private var colorScheme

    private var theme: CorbieTheme {
        environment.theme.activeTheme
    }

    var body: some View {
        RootView()
            .environment(appState)
            .environment(environment)
            .environment(environment.premiumGate)
            .environment(environment.toasts)
            .environment(environment.theme)
            .toastHost()
            .corbieTheme(theme)
            .tint(theme.palette.accent)
            .preferredColorScheme(environment.theme.preferredColorScheme)
            .onChange(of: colorScheme, initial: true) { _, scheme in
                environment.theme.systemScheme = scheme
            }
    }
}

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate {
    private let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "sharing")

    private(set) lazy var environment = AppDelegate.makeEnvironment()
    private(set) lazy var appState = AppState()
    #if DEBUG
    private(set) lazy var screenshotMode = ScreenshotModeSwitch(real: environment, appState: appState)
    #endif

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        environment.startProcess()
        #if DEBUG
        screenshotMode.start()
        #endif
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        let environment = environment
        let sync = environment.remotePushSync(scope: RemotePushSync.scope(ofPush: userInfo))
        Task {
            let outcome = await Deadline.run(within: RemotePushSync.budget) {
                await environment.processReady()
                return await sync.finish()
            }
            completionHandler((outcome ?? sync.progress).fetchResult)
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

    private static func makeEnvironment() -> AppEnvironment {
        #if DEBUG
        DebugLaunch.resetStoreIfRequested()
        DebugLaunch.applyEntitlementArgument()
        DebugLaunch.applyMonetizationArgument()
        #endif
        return AppEnvironment()
    }

    private func perform(_ response: NotificationResponse) async {
        switch NotificationRouting.outcome(for: response) {
        case let .takeTask(taskId):
            await write { persistence in
                try await TaskIntentRunner.take(taskId: taskId, persistence: persistence)
            }
        case let .completeTask(taskId):
            await write { persistence in
                try await TaskIntentRunner.markDone(taskId: taskId, persistence: persistence)
                await self.environment.notifications.cancelTaskDueToday(taskId: taskId)
            }
        case let .open(route):
            appState.open(route)
        case .ignored:
            break
        }
    }

    private func write(_ body: (IntentPersistence) async throws -> Void) async {
        await environment.processReady()
        let persistence = IntentPersistence.pinned(to: environment.persistence, identity: environment.identity)
        do {
            try await body(persistence)
        } catch {
            environment.report(error)
        }
    }
}

private extension RemotePushOutcome {
    var fetchResult: UIBackgroundFetchResult {
        switch self {
        case .newData: return .newData
        case .noData: return .noData
        case .failed: return .failed
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
            await perform(parsed)
            completionHandler()
        }
    }
}
