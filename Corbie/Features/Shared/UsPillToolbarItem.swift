import CorbieCore
import SwiftUI

struct UsPillToolbarItem: ToolbarContent {
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            UsPillButton()
        }
    }
}

struct UsPillButton: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(AppState.self) private var appState

    private var label: LocalizedStringKey {
        environment.usBadge.showsDot ? "us.pill.label.new" : "us.pill.label"
    }

    var body: some View {
        Button {
            appState.isUsHubPresented = true
        } label: {
            UsPill(
                slotA: environment.memberSlot(id: environment.currentMember?.id),
                slotB: environment.memberSlot(id: environment.partner?.id),
                badge: environment.usBadge.showsDot
            )
        }
        .accessibilityLabel(Text(label))
        .task(id: environment.session) {
            await environment.usBadge.refresh(
                space: environment.space,
                viewer: environment.currentMember,
                partner: environment.partner
            )
        }
    }
}
