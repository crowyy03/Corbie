import CorbieCore
import SwiftUI

struct GoalStepEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: GoalStepEditorViewModel

    init(step: GoalStepDTO) {
        _model = State(initialValue: GoalStepEditorViewModel(step: step))
    }

    var body: some View {
        @Bindable var model = model

        return GoalsEditorScaffold(
            title: String(localized: "goals.step.editor.title"),
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
                label: String(localized: "goals.step.field.title"),
                placeholder: String(localized: "goals.step.field.title.placeholder"),
                text: $model.title
            )
            GoalsChipsField(
                label: String(localized: "goals.step.field.who"),
                values: model.assigneeOptions,
                title: { model.title(for: $0) },
                selection: $model.assignee
            )
            FieldRow(
                label: String(localized: "goals.step.field.due"),
                hint: String(localized: "goals.detail.steps.hint")
            ) {
                VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                    Toggle(isOn: $model.hasDue) {
                        Text("goals.step.due.toggle")
                            .corbieBody()
                            .foregroundStyle(CorbieColorPalette.text)
                    }
                    .tint(CorbieColorPalette.ice)
                    .frame(minHeight: CorbieMetrics.minimumTapTarget)
                    if model.hasDue {
                        GoalsDateField(
                            label: String(localized: "goals.step.field.due"),
                            date: $model.dueAt
                        )
                    }
                }
            }
            GoalsNoteField(
                label: String(localized: "goals.step.field.note"),
                placeholder: String(localized: "goals.step.field.note.placeholder"),
                text: $model.note
            )
        }
        .task {
            model.attach(environment)
        }
    }
}

#if DEBUG
#Preview {
    GoalStepEditorView(step: GoalStepDTO(id: UUID(), title: "Collect the documents"))
        .environment(AppEnvironment.previewSignedIn())
}
#endif
