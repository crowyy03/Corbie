import CorbieCore
import SwiftUI

struct UsPillToolbarItem: ToolbarContent {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppState.self) private var appState

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                appState.isUsHubPresented = true
            } label: {
                UsPill(
                    colorA: environment.memberColor(id: environment.currentMember?.id),
                    colorB: environment.memberColor(id: environment.partner?.id)
                )
            }
            .accessibilityLabel(Text("us.pill.label"))
        }
    }
}
