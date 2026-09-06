import CorbieCore
import SwiftUI

struct VoteEditorView: View {
    private let onFinish: () async -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model = VoteEditorViewModel()

    init(onFinish: @escaping () async -> Void) {
        self.onFinish = onFinish
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    templates
                    TextFieldRow(
                        label: String(localized: "votes.editor.question"),
                        placeholder: String(localized: "votes.editor.question.placeholder"),
                        text: $model.question
                    )
                    optionRows
                    modeRow
                    revealRow
                }
                .padding(CorbieSpacing.l)
            }
            .background(CorbieColorPalette.bg)
            .navigationTitle(String(localized: "votes.action.new"))
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
                            guard model.didFinish else { return }
                            await onFinish()
                            dismiss()
                        }
                    }
                    .disabled(model.canSave == false)
                }
            }
        }
        .onAppear {
            model.attach(environment)
        }
    }

    private var templates: some View {
        FieldRow(label: String(localized: "votes.editor.template")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CorbieSpacing.xs) {
                    ForEach(VoteTemplate.allCases) { template in
                        Button {
                            model.apply(template)
                        } label: {
                            Chip(label: template.title, isSelected: model.template == template)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, CorbieSpacing.xxs)
            }
        }
    }

    private var optionRows: some View {
        FieldRow(
            label: String(localized: "votes.editor.options"),
            hint: String(localized: "votes.editor.options.hint")
        ) {
            VStack(spacing: CorbieSpacing.xs) {
                ForEach(Array(model.options.indices), id: \.self) { index in
                    HStack(spacing: CorbieSpacing.xs) {
                        TextField(
                            String(localized: "votes.editor.option.placeholder \(index + 1)"),
                            text: optionBinding(index)
                        )
                        .textFieldStyle(.plain)
                        .corbieBody()
                        .foregroundStyle(CorbieColorPalette.text)
                        .padding(.horizontal, CorbieSpacing.s)
                        .frame(minHeight: CorbieMetrics.minimumTapTarget)
                        .corbieFieldBox()
                        if model.canRemoveOption {
                            Button {
                                model.removeOption(at: index)
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(CorbieColorPalette.text2)
                                    .frame(
                                        width: CorbieMetrics.minimumTapTarget,
                                        height: CorbieMetrics.minimumTapTarget
                                    )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text("votes.editor.option.remove"))
                        }
                    }
                }
                if model.canAddOption {
                    SecondaryButton(title: String(localized: "votes.editor.option.add")) {
                        model.addOption()
                    }
                }
            }
        }
    }

    private var modeRow: some View {
        FieldRow(
            label: String(localized: "votes.editor.mode"),
            hint: String(localized: "votes.editor.mode.hint")
        ) {
            SegmentedPicker(selection: $model.mode, options: VoteMode.allCases) { mode in
                mode == .single
                    ? String(localized: "votes.editor.mode.single")
                    : String(localized: "votes.editor.mode.multi")
            }
        }
    }

    private var revealRow: some View {
        Toggle(isOn: $model.revealWhenBothAnswered) {
            VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                Text("votes.editor.reveal")
                    .corbieBody()
                    .foregroundStyle(CorbieColorPalette.text)
                Text("votes.editor.reveal.hint")
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
            }
        }
        .tint(CorbieColorPalette.ice)
        .frame(minHeight: CorbieMetrics.minimumTapTarget)
    }

    private func optionBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { model.options.indices.contains(index) ? model.options[index] : "" },
            set: { newValue in
                guard model.options.indices.contains(index) else { return }
                model.options[index] = newValue
            }
        )
    }
}

#if DEBUG
#Preview {
    VoteEditorView {}
        .environment(AppEnvironment.preview())
}
#endif
