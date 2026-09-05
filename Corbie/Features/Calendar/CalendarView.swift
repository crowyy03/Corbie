import SwiftUI

struct CalendarView: View {
    var body: some View {
        PlaceholderView(
            title: String(localized: "calendar.placeholder.title"),
            note: String(localized: "calendar.placeholder.note")
        )
        .navigationTitle(String(localized: "tab.calendar.title"))
        .toolbar {
            AddToolbarItem {
            }
            UsPillToolbarItem()
        }
    }
}

#Preview {
    NavigationStack {
        CalendarView()
    }
    .environment(AppState())
}
