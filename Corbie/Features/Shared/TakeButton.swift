import CorbieCore
import SwiftUI

struct TakeButton: View {
    @Environment(\.palette) private var palette

    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("tasks.action.take")
                .corbieCaption()
                .fontWeight(.semibold)
                .foregroundStyle(palette.ctaText)
                .padding(.horizontal, CorbieSpacing.s)
                .frame(minHeight: CorbieMetrics.chipHeight)
                .background(Capsule(style: .continuous).fill(palette.accent))
        }
        .buttonStyle(.plain)
        .frame(minWidth: CorbieMetrics.minimumTapTarget, minHeight: CorbieMetrics.minimumTapTarget)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(String(format: String(localized: "tasks.action.take.accessibility"), title)))
    }
}
