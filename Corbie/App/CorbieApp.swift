import CloudKit
import CorbieCore
import os
import SwiftUI
import UIKit

@main
struct CorbieApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()
    @State private var environment = AppEnvironment()

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

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        completionHandler(.noData)
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
}
