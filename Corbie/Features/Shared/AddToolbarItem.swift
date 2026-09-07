import CorbieCore
import SwiftUI

struct AddButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(CorbieColorPalette.text)
                .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("common.action.add"))
    }
}

struct AddToolbarItem: ToolbarContent {
    let action: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            AddButton(action: action)
        }
    }
}
