import CorbieCore
import SwiftUI

struct GiftIdeaEditorView: View {
    @Environment(\.palette) private var palette

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditingLink: Bool
    @State private var model: GiftIdeaEditorViewModel

    init(personId: UUID, mode: GiftIdeaEditorMode) {
        _model = State(initialValue: GiftIdeaEditorViewModel(personId: personId, mode: mode))
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    linkField
                    TextFieldRow(
                        label: String(localized: "people.gift.title"),
                        placeholder: String(localized: "people.gift.title.placeholder"),
                        text: $model.title
                    )
                    .redacted(reason: model.isParsing ? .placeholder : [])
                    .disabled(model.isParsing)
                    priceField
                    TextFieldRow(
                        label: String(localized: "people.gift.note"),
                        placeholder: String(localized: "people.gift.note.placeholder"),
                        text: $model.note
                    )
                }
                .padding(.horizontal, CorbieSpacing.l)
                .padding(.vertical, CorbieSpacing.m)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(palette.bg)
            .navigationTitle(Text(titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "people.editor.cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "people.editor.save")) {
                        Task {
                            if await model.save() { dismiss() }
                        }
                    }
                    .disabled(model.canSave == false)
                }
            }
        }
        .onAppear {
            model.bind(environment)
        }
    }

    private var titleKey: LocalizedStringKey {
        model.mode.idea == nil ? "people.gift.editor.title.new" : "people.gift.editor.title.edit"
    }

    private var linkField: some View {
        @Bindable var model = model

        return FieldRow(
            label: String(localized: "people.gift.link"),
            hint: model.hasFailedLink
                ? String(localized: "people.gift.link.failed")
                : String(localized: "people.gift.link.hint")
        ) {
            HStack(spacing: CorbieSpacing.xs) {
                TextField(String(localized: "people.gift.link.placeholder"), text: $model.link)
                    .textFieldStyle(.plain)
                    .corbieBody()
                    .foregroundStyle(palette.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($isEditingLink)
                    .submitLabel(.done)
                    .onSubmit {
                        Task { await model.parseLinkIfNeeded() }
                    }
                    .accessibilityLabel(Text("people.gift.link"))
                if model.isParsing {
                    ProgressView()
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, CorbieSpacing.s)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
            .corbieFieldBox()
            .onChange(of: isEditingLink) {
                guard isEditingLink == false else { return }
                Task { await model.parseLinkIfNeeded() }
            }
        }
    }

    private var priceField: some View {
        @Bindable var model = model

        return FieldRow(label: String(localized: "people.gift.price")) {
            HStack(spacing: CorbieSpacing.xs) {
                TextField(String(localized: "people.gift.price.placeholder"), text: $model.priceText)
                    .textFieldStyle(.plain)
                    .corbieBody()
                    .foregroundStyle(palette.text)
                    .keyboardType(.decimalPad)
                    .padding(.horizontal, CorbieSpacing.s)
                    .frame(minHeight: CorbieMetrics.minimumTapTarget)
                    .corbieFieldBox()
                    .accessibilityLabel(Text("people.gift.price"))

                Picker(selection: $model.currency) {
                    ForEach(model.currencies, id: \.self) { code in
                        Text(code).tag(code)
                    }
                } label: {
                    Text("people.gift.currency")
                }
                .pickerStyle(.menu)
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
                .accessibilityLabel(Text("people.gift.currency"))
            }
        }
        .redacted(reason: model.isParsing ? .placeholder : [])
        .disabled(model.isParsing)
    }
}

#if DEBUG
#Preview {
    GiftIdeaEditorView(personId: UUID(), mode: .new)
        .environment(AppEnvironment.preview())
}
#endif
