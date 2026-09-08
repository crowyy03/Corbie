import CorbieCore
import SwiftUI

struct PlanStepEditorView: View {
    @Environment(\.palette) private var palette

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: PlanStepEditorViewModel

    init(step: PlanStepDTO) {
        _model = State(initialValue: PlanStepEditorViewModel(step: step))
    }

    var body: some View {
        @Bindable var model = model

        return PlansEditorScaffold(
            title: String(localized: "plans.step.editor.title"),
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
                label: String(localized: "plans.step.field.title"),
                placeholder: String(localized: "plans.step.field.title.placeholder"),
                text: $model.title
            )
            PlansChipsField(
                label: String(localized: "plans.step.field.who"),
                values: model.assigneeOptions,
                title: { model.title(for: $0) },
                selection: $model.assignee
            )
            FieldRow(
                label: String(localized: "plans.step.field.due"),
                hint: String(localized: "plans.detail.steps.hint")
            ) {
                VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                    Toggle(isOn: $model.hasDue) {
                        Text("plans.step.due.toggle")
                            .corbieBody()
                            .foregroundStyle(palette.text)
                    }
                    .tint(palette.accent)
                    .frame(minHeight: CorbieMetrics.minimumTapTarget)
                    if model.hasDue {
                        PlansDateField(
                            label: String(localized: "plans.step.field.due"),
                            date: $model.dueAt
                        )
                    }
                }
            }
            PlansNoteField(
                label: String(localized: "plans.step.field.note"),
                placeholder: String(localized: "plans.step.field.note.placeholder"),
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
    PlanStepEditorView(step: PlanStepDTO(id: UUID(), title: "Collect the documents"))
        .environment(AppEnvironment.previewSignedIn())
}
#endif
