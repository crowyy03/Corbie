import SwiftUI

struct UsView: View {
    var body: some View {
        UsHubView()
            .navigationTitle(String(localized: "tab.us.title"))
            .toolbar {
                AddToolbarItem {
                }
                UsPillToolbarItem()
            }
    }
}

#Preview {
    NavigationStack {
        UsView()
    }
    .environment(AppState())
}
