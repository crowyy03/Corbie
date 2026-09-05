import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var state = appState
        @Bindable var gate = environment.premiumGate

        TabView(selection: $state.selectedTab) {
            NavigationStack {
                TasksView()
            }
            .tabItem {
                Label(String(localized: "tab.tasks.title"), systemImage: "checkmark.circle")
            }
            .tag(AppState.Tab.tasks)

            NavigationStack {
                CalendarView()
            }
            .tabItem {
                Label(String(localized: "tab.calendar.title"), systemImage: "calendar")
            }
            .tag(AppState.Tab.calendar)

            NavigationStack {
                WishesView()
            }
            .tabItem {
                Label(String(localized: "tab.wishes.title"), systemImage: "star")
            }
            .tag(AppState.Tab.wishes)

            NavigationStack {
                PlansView()
            }
            .tabItem {
                Label(String(localized: "tab.plans.title"), systemImage: "flag")
            }
            .tag(AppState.Tab.plans)

            NavigationStack {
                UsView()
            }
            .tabItem {
                Label(String(localized: "tab.us.title"), systemImage: "person.2")
            }
            .tag(AppState.Tab.us)
        }
        .sheet(isPresented: $state.isUsHubPresented) {
            UsHubSheet()
        }
        .sheet(item: $gate.pendingPaywall) { request in
            PaywallView(request: request)
        }
    }
}

private struct UsHubSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            UsHubView()
                .navigationTitle(String(localized: "us.hub.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(String(localized: "common.action.done")) {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
        .environment(AppEnvironment.preview())
}
