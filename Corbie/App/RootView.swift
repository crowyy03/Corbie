import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        TabView(selection: $state.selectedTab) {
            TabScaffold(title: String(localized: "tab.tasks.title")) {
                TasksView()
            }
            .tabItem {
                Label(String(localized: "tab.tasks.title"), systemImage: "checkmark.circle")
            }
            .tag(AppState.Tab.tasks)

            TabScaffold(title: String(localized: "tab.calendar.title")) {
                CalendarView()
            }
            .tabItem {
                Label(String(localized: "tab.calendar.title"), systemImage: "calendar")
            }
            .tag(AppState.Tab.calendar)

            TabScaffold(title: String(localized: "tab.wishes.title")) {
                WishesView()
            }
            .tabItem {
                Label(String(localized: "tab.wishes.title"), systemImage: "star")
            }
            .tag(AppState.Tab.wishes)

            TabScaffold(title: String(localized: "tab.plans.title")) {
                PlansView()
            }
            .tabItem {
                Label(String(localized: "tab.plans.title"), systemImage: "flag")
            }
            .tag(AppState.Tab.plans)

            TabScaffold(title: String(localized: "tab.us.title")) {
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
    }
}

private struct TabScaffold<Content: View>: View {
    @Environment(AppState.self) private var appState

    private let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title)
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel(Text("common.action.add"))

                        UsPillButton {
                            appState.isUsHubPresented = true
                        }
                    }
                }
        }
    }
}

private struct UsPillButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: -6) {
                Circle()
                    .fill(.tint)
                    .frame(width: 16, height: 16)
                Circle()
                    .fill(.secondary)
                    .frame(width: 16, height: 16)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .overlay {
                Capsule().stroke(.quaternary)
            }
        }
        .accessibilityLabel(Text("us.pill.label"))
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
}
