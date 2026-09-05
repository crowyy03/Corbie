import SwiftUI

struct CalendarView: View {
    var body: some View {
        PlaceholderView(
            title: String(localized: "calendar.placeholder.title"),
            note: String(localized: "calendar.placeholder.note")
        )
    }
}

#Preview {
    CalendarView()
}
