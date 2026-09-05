import SwiftUI

struct TasksView: View {
    var body: some View {
        PlaceholderView(
            title: String(localized: "tasks.placeholder.title"),
            note: String(localized: "tasks.placeholder.note")
        )
    }
}

#Preview {
    TasksView()
}
