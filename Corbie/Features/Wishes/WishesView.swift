import SwiftUI

struct WishesView: View {
    var body: some View {
        PlaceholderView(
            title: String(localized: "wishes.placeholder.title"),
            note: String(localized: "wishes.placeholder.note")
        )
        .navigationTitle(String(localized: "tab.wishes.title"))
        .toolbar {
            AddToolbarItem {
            }
            UsPillToolbarItem()
        }
    }
}

#Preview {
    NavigationStack {
        WishesView()
    }
    .environment(AppState())
}
