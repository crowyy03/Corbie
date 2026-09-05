import SwiftUI

struct TasksView: View {
    var body: some View {
        PlaceholderView(
            title: String(localized: "tasks.placeholder.title"),
            note: String(localized: "tasks.placeholder.note")
        )
        .navigationTitle(String(localized: "tab.tasks.title"))
        .toolbar {
            AddToolbarItem {
            }
            UsPillToolbarItem()
        }
    }
}

#Preview {
    NavigationStack {
        TasksView()
    }
    .environment(AppState())
}
