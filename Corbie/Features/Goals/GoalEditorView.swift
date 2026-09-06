import CorbieCore
import SwiftUI

struct GoalEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: GoalEditorViewModel

    init(goal: GoalDTO?) {
        _model = State(initialValue: GoalEditorViewModel(goal: goal))
    }

    var body: some View {
        GoalsEditorScaffold(
            title: String(localized: model.isEditing ? "goals.editor.title.edit" : "goals.editor.title.new"),
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
                label: String(localized: "goals.editor.field.title"),
                placeholder: String(localized: "goals.editor.field.title.placeholder"),
                text: $model.title
            )
            GoalsChipsField(
                label: String(localized: "goals.editor.field.type"),
                values: GoalType.allCases,
                title: { GoalsCopy.text($0.titleKey) },
                selection: $model.type
            )
            GoalsAmountField(
                label: String(localized: "goals.editor.field.target"),
                amount: $model.targetAmount
            )
            GoalsCurrencyField(
                label: String(localized: "goals.editor.field.currency"),
                currencies: model.currencies,
                selection: $model.currency
            )
            GoalsAmountField(
                label: String(localized: "goals.editor.field.saved"),
                hint: String(localized: "goals.editor.field.saved.hint"),
                amount: $model.savedAmount
            )
            Toggle(isOn: $model.hasDates) {
                Text("goals.editor.field.dates")
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
            }
            .tint(CorbieColorPalette.ice)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
            if model.hasDates {
                GoalsDateField(
                    label: String(localized: "goals.editor.field.start"),
                    date: $model.startAt
                )
                GoalsDateField(
                    label: String(localized: "goals.editor.field.end"),
                    range: model.startAt...,
                    date: $model.endAt
                )
            }
            GoalsNoteField(
                label: String(localized: "goals.editor.field.note"),
                placeholder: String(localized: "goals.editor.field.note.placeholder"),
                text: $model.note
            )
            GoalsInfoBlock(text: String(localized: "goals.editor.info"))
        }
        .task {
            model.attach(environment)
        }
    }
}

#if DEBUG
#Preview {
    GoalEditorView(goal: nil)
        .environment(AppEnvironment.preview())
}
#endif
