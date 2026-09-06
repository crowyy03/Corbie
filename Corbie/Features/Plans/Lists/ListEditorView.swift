import CorbieCore
import SwiftUI

struct ListEditorView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: ListEditorViewModel

    init(list: ChecklistListDTO?) {
        _model = State(initialValue: ListEditorViewModel(list: list))
    }

    var body: some View {
        PlansEditorScaffold(
            title: String(localized: model.isEditing ? "lists.editor.title.edit" : "lists.editor.title.new"),
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
                label: String(localized: "lists.editor.field.title"),
                placeholder: String(localized: "lists.editor.field.title.placeholder"),
                text: $model.title
            )
            TextFieldRow(
                label: String(localized: "lists.editor.field.subtitle"),
                placeholder: model.subtitlePlaceholder,
                text: $model.subtitle
            )
            PlansChipsField(
                label: String(localized: "lists.editor.field.template"),
                values: ListTemplate.allCases,
                title: { PlansCopy.text($0.titleKey) },
                selection: $model.template
            )
            Toggle(isOn: $model.anyoneCanCheck) {
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    Text("lists.editor.field.anyone")
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                    Text("lists.editor.field.anyone.hint")
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
            }
            .tint(CorbieColorPalette.ice)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
        }
        .task {
            model.attach(environment)
        }
    }
}

#if DEBUG
#Preview {
    ListEditorView(list: nil)
        .environment(AppEnvironment.preview())
}
#endif
