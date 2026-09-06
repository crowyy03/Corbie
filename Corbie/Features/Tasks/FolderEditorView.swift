import CorbieCore
import SwiftUI

struct FolderEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: FolderEditorViewModel

    private let onSaved: (TaskFolderDTO) -> Void

    init(model: FolderEditorViewModel, onSaved: @escaping (TaskFolderDTO) -> Void) {
        _model = State(initialValue: model)
        self.onSaved = onSaved
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    TextFieldRow(
                        label: String(localized: "tasks.folder.editor.field.title"),
                        placeholder: model.titlePlaceholder,
                        text: $model.title
                    )

                    TextFieldRow(
                        label: String(localized: "tasks.folder.editor.field.subtitle"),
                        placeholder: String(localized: "tasks.folder.editor.field.subtitle.placeholder"),
                        text: $model.subtitle
                    )

                    FieldRow(
                        label: String(localized: "tasks.folder.editor.field.template"),
                        hint: model.template.itemPlaceholder
                    ) {
                        ScrollView(.horizontal) {
                            HStack(spacing: CorbieSpacing.xs) {
                                ForEach(FolderTemplate.allCases, id: \.self) { template in
                                    Button {
                                        model.template = template
                                    } label: {
                                        Chip(label: template.title, isSelected: model.template == template)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, CorbieMetrics.hairline)
                        }
                        .scrollIndicators(.hidden)
                    }

                    FieldRow(
                        label: String(localized: "tasks.folder.editor.field.anyone"),
                        hint: String(localized: "tasks.folder.editor.field.anyone.hint")
                    ) {
                        Toggle(isOn: $model.anyoneCanCheck) {
                            Text("tasks.folder.editor.field.anyone")
                                .corbieBody()
                                .foregroundStyle(CorbieColorPalette.text)
                        }
                        .tint(CorbieColorPalette.ice)
                        .frame(minHeight: CorbieMetrics.minimumTapTarget)
                    }
                }
                .padding(CorbieSpacing.l)
            }
            .background(CorbieColorPalette.bg)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(Text(model.isEditing ? "tasks.folder.editor.title.edit" : "tasks.folder.editor.title.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("common.action.cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("common.action.save") {
                        Task {
                            guard let saved = await model.save() else { return }
                            onSaved(saved)
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(model.canSave == false)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    let environment = AppEnvironment.preview()
    return FolderEditorView(
        model: FolderEditorViewModel(
            folder: nil,
            context: TasksContext(spaceId: UUID(), memberId: UUID()),
            repository: environment.repositories.tasks,
            analytics: environment.analytics
        )
    ) { _ in }
}
#endif
