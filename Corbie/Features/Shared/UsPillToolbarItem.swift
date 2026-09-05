import CorbieCore
import SwiftUI

struct UsPillToolbarItem: ToolbarContent {
    @Environment(AppState.self) private var appState

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                appState.isUsHubPresented = true
            } label: {
                UsPill(
                    colorA: MemberColorKey.defaultA.color,
                    colorB: MemberColorKey.defaultB.color
                )
            }
            .accessibilityLabel(Text("us.pill.label"))
        }
    }
}
