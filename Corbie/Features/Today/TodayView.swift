import CorbieCore
import SwiftUI

struct TodayView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        EmptyState(
            systemImage: "sun.max",
            title: String(localized: "today.empty.title"),
            monoNote: String(localized: "today.empty.note")
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CorbieColorPalette.bg)
        .navigationTitle(String(localized: "tab.today.title"))
        .toolbar {
            UsPillToolbarItem()
        }
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        TodayView()
    }
    .environment(AppState())
    .environment(AppEnvironment.preview())
}
#endif
