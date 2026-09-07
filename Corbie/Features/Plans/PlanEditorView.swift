import CorbieCore
import SwiftUI

struct PlanEditorView: View {
    @Environment(\.palette) private var palette

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: PlanEditorViewModel

    init(plan: PlanDTO?) {
        _model = State(initialValue: PlanEditorViewModel(plan: plan))
    }

    var body: some View {
        PlansEditorScaffold(
            title: String(localized: model.isEditing ? "plans.editor.title.edit" : "plans.editor.title.new"),
            saveTitle: String(localized: "common.action.save"),
            canSave: model.canSave,
            onCancel: { dismiss() },
            onSave: {
                Task {
                    if await model.save() { dismiss() }
                }
            }
        ) {
            TextFieldRow(
                label: String(localized: "plans.editor.field.title"),
                placeholder: String(localized: "plans.editor.field.title.placeholder"),
                text: $model.title
            )
            PlansChipsField(
                label: String(localized: "plans.editor.field.type"),
                values: PlanType.allCases,
                title: { PlansCopy.text($0.titleKey) },
                selection: $model.type
            )
            PlansAmountField(
                label: String(localized: "plans.editor.field.target"),
                amount: $model.targetAmount
            )
            PlansCurrencyField(
                label: String(localized: "plans.editor.field.currency"),
                currencies: model.currencies,
                selection: $model.currency
            )
            PlansAmountField(
                label: String(localized: "plans.editor.field.saved"),
                hint: String(localized: "plans.editor.field.saved.hint"),
                amount: $model.savedAmount
            )
            Toggle(isOn: $model.hasDates) {
                Text("plans.editor.field.dates")
                    .corbieBody()
                    .foregroundStyle(palette.text)
            }
            .tint(palette.accent)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
            if model.hasDates {
                PlansDateField(
                    label: String(localized: "plans.editor.field.start"),
                    date: $model.startAt
                )
                PlansDateField(
                    label: String(localized: "plans.editor.field.end"),
                    range: model.startAt...,
                    date: $model.endAt
                )
            }
            PlansNoteField(
                label: String(localized: "plans.editor.field.note"),
                placeholder: String(localized: "plans.editor.field.note.placeholder"),
                text: $model.note
            )
            PlansInfoBlock(text: String(localized: "plans.editor.info"))
        }
        .task {
            model.attach(environment)
        }
    }
}

#if DEBUG
#Preview {
    PlanEditorView(plan: nil)
        .environment(AppEnvironment.preview())
}
#endif
