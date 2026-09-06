import CorbieCore
import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase

    @State private var pendingJoinCode: String?
    @State private var joinRequest: JoinRequest?
    @State private var isUsHubOnScreen = false
    @State private var isLaunchRevealShown = true

    private let credentials = AppleCredentialMonitor()
    private let partnerWatcher = PartnerJoinWatcher()

    var body: some View {
        content
            .overlay {
                if isLaunchRevealShown {
                    LaunchRevealView(isReady: environment.session != .loading) {
                        isLaunchRevealShown = false
                    }
                    .transition(.opacity)
                }
            }
            .paywallRuntime()
            .task {
                await credentials.verifyStoredCredential(environment)
                await credentials.observeRevocation(environment)
            }
            .task(id: appState.route) { consumeJoinRoute() }
            .task(id: environment.session) { consumeJoinRoute() }
    }

    @ViewBuilder private var content: some View {
        switch environment.session {
        case .loading:
            LaunchPlaceholderView()
        case .signedOut:
            OnboardingView(environment: environment, appState: appState, joinCode: pendingJoinCode)
        case .signedIn:
            signedIn
        }
    }

    private var signedIn: some View {
        @Bindable var state = appState

        return TabView(selection: $state.selectedTab) {
            NavigationStack {
                TasksView()
                    .paywallBanner()
            }
            .tabItem {
                Label(String(localized: "tab.tasks.title"), systemImage: "checkmark.circle")
            }
            .tag(AppState.Tab.tasks)

            NavigationStack {
                CalendarView()
                    .paywallBanner()
            }
            .tabItem {
                Label(String(localized: "tab.calendar.title"), systemImage: "calendar")
            }
            .tag(AppState.Tab.calendar)

            NavigationStack {
                WishesView()
                    .paywallBanner()
            }
            .tabItem {
                Label(String(localized: "tab.wishes.title"), systemImage: "star")
            }
            .tag(AppState.Tab.wishes)

            NavigationStack {
                PlansView()
                    .paywallBanner()
            }
            .tabItem {
                Label(String(localized: "tab.plans.title"), systemImage: "flag")
            }
            .tag(AppState.Tab.plans)

            UsView()
            .tabItem {
                Label(String(localized: "tab.us.title"), systemImage: "person.2")
            }
            .tag(AppState.Tab.us)
        }
        .fullScreenCover(isPresented: $state.isUsHubPresented) {
            UsHubSheet()
                .onAppear { isUsHubOnScreen = true }
                .onDisappear { isUsHubOnScreen = false }
        }
        .sheet(item: paywallRequest) { request in
            PaywallView(request: request)
        }
        .sheet(item: $joinRequest) { request in
            JoinSheet(code: request.code)
        }
        .task { await partnerWatcher.observe(environment) }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await partnerWatcher.check(environment) }
        }
    }

    private var paywallRequest: Binding<PaywallRequest?> {
        Binding(
            get: { isUsHubOnScreen ? nil : environment.premiumGate.pendingPaywall },
            set: { request in
                guard request == nil else { return }
                environment.premiumGate.dismissPaywall()
            }
        )
    }

    private func consumeJoinRoute() {
        guard case let .join(code) = appState.route else { return }
        switch environment.session {
        case .loading:
            return
        case .signedOut:
            pendingJoinCode = code
        case .signedIn:
            joinRequest = JoinRequest(code: code)
        }
        appState.route = nil
    }
}

struct JoinRequest: Identifiable, Equatable {
    let id = UUID()
    let code: String
}

private struct UsHubSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            UsHubView()
                .usDestinations()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(Text("common.action.close"))
                    }
                }
        }
    }
}

#if DEBUG
#Preview("Signed in") {
    RootView()
        .environment(AppState())
        .environment(AppEnvironment.previewSignedIn())
}

#Preview("Signed out") {
    RootView()
        .environment(AppState())
        .environment(AppEnvironment.previewSignedOut())
}
#endif
