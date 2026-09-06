import CorbieCore
import SwiftUI

struct GoalStepComposer: View {
    @Binding var title: String
    let canAdd: Bool
    let add: () -> Void

    @FocusState private var isFocused: Bool

    private func submit() {
        add()
        isFocused = true
    }

    var body: some View {
        HStack(spacing: CorbieSpacing.xs) {
            TextField(String(localized: "goals.detail.steps.add.placeholder"), text: $title)
                .textFieldStyle(.plain)
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
                .focused($isFocused)
                .submitLabel(.done)
                .onSubmit(submit)
                .padding(.horizontal, CorbieSpacing.s)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
                .corbieFieldBox()
                .accessibilityLabel(Text("goals.detail.steps.add.placeholder"))
            Button(action: submit) {
                Image(systemName: "plus")
                    .foregroundStyle(canAdd ? CorbieColorPalette.text : CorbieColorPalette.text2)
                    .frame(minWidth: CorbieMetrics.minimumTapTarget, minHeight: CorbieMetrics.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(canAdd == false)
            .accessibilityLabel(Text("goals.detail.steps.add.action"))
        }
    }
}

#if DEBUG
private struct GoalStepComposerPreview: View {
    @State private var title = ""

    var body: some View {
        GoalStepComposer(title: $title, canAdd: title.isEmpty == false) {}
            .padding(CorbieSpacing.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(CorbieColorPalette.bg)
    }
}

#Preview {
    GoalStepComposerPreview()
}
#endif
