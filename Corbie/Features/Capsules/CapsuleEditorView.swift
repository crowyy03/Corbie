import CorbieCore
import SwiftUI

struct CapsuleEditorView: View {
    private let onFinish: () async -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model: CapsuleEditorViewModel
    @State private var isDeleteConfirmationPresented = false

    init(target: CapsuleEditorTarget, onFinish: @escaping () async -> Void) {
        self.onFinish = onFinish
        _model = State(initialValue: CapsuleEditorViewModel(target: target))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    recipient
                    TextFieldRow(
                        label: String(localized: "capsules.editor.title"),
                        placeholder: String(localized: "capsules.editor.title.placeholder"),
                        text: $model.title
                    )
                    letter
                    opening
                    if model.isExisting {
                        SecondaryButton(title: String(localized: "capsules.editor.delete")) {
                            isDeleteConfirmationPresented = true
                        }
                        .padding(.top, CorbieSpacing.s)
                    }
                }
                .padding(CorbieSpacing.l)
            }
            .background(CorbieColorPalette.bg)
            .navigationTitle(
                model.isExisting
                    ? String(localized: "capsules.editor.edit")
                    : String(localized: "capsules.action.new")
            )
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
                            await model.save()
                            await finishIfNeeded()
                        }
                    }
                    .disabled(model.canSave == false)
                }
            }
            .confirmationDialog(
                String(localized: "capsules.editor.delete.confirm"),
                isPresented: $isDeleteConfirmationPresented,
                titleVisibility: .visible
            ) {
                Button("capsules.editor.delete", role: .destructive) {
                    Task {
                        await model.delete()
                        await finishIfNeeded()
                    }
                }
                Button("common.action.cancel", role: .cancel) {}
            }
        }
        .onAppear {
            model.attach(environment)
        }
    }

    private var recipient: some View {
        FieldRow(
            label: String(localized: "capsules.editor.to"),
            hint: String(localized: "capsules.editor.to.hint")
        ) {
            HStack(spacing: CorbieSpacing.xs) {
                MemberDot(color: environment.memberColor(id: environment.partner?.id))
                Text(environment.partnerName)
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
            }
            .frame(minHeight: CorbieMetrics.minimumTapTarget, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private var letter: some View {
        FieldRow(
            label: String(localized: "capsules.editor.body"),
            hint: String(localized: "capsules.editor.body.left \(model.remainingCharacters)")
        ) {
            TextEditor(text: $model.letter)
                .corbieBody()
                .foregroundStyle(CorbieColorPalette.text)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 180)
                .padding(CorbieSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
                        .fill(CorbieColorPalette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
                        .strokeBorder(CorbieColorPalette.border, lineWidth: CorbieMetrics.hairline)
                )
                .accessibilityLabel(Text("capsules.editor.body"))
        }
    }

    private var opening: some View {
        FieldRow(
            label: String(localized: "capsules.editor.opens"),
            hint: String(localized: "capsules.editor.opens.hint")
        ) {
            DatePicker(
                String(localized: "capsules.editor.opens"),
                selection: $model.opensAt,
                in: model.earliestOpening...,
                displayedComponents: .date
            )
            .labelsHidden()
            .frame(minHeight: CorbieMetrics.minimumTapTarget, alignment: .leading)
            .accessibilityLabel(Text("capsules.editor.opens"))
        }
    }

    private func finishIfNeeded() async {
        guard model.didFinish else { return }
        await onFinish()
        dismiss()
    }
}

#Preview {
    CapsuleEditorView(target: .new) {}
        .environment(AppEnvironment.preview())
}
