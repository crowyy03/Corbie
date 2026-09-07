import CorbieCore
import PhotosUI
import SwiftUI

struct WishEditorView: View {
    @Environment(\.palette) private var palette

    let request: WishEditorRequest
    let onSaved: () async -> Void

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = WishEditorViewModel()
    @State private var photo: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    linkField
                    photoField
                    TextFieldRow(
                        label: String(localized: "wishes.editor.name"),
                        placeholder: String(localized: "wishes.editor.name.placeholder"),
                        text: $viewModel.title
                    )
                    priceField
                    priorityField
                    TextFieldRow(
                        label: String(localized: "wishes.editor.note"),
                        placeholder: String(localized: "wishes.editor.note.placeholder"),
                        text: $viewModel.note
                    )
                    ownerToggle
                    PrimaryButton(title: String(localized: "common.action.save")) {
                        Task { await save() }
                    }
                    .disabled(viewModel.canSave == false)
                    .padding(.top, CorbieSpacing.xs)
                }
                .padding(CorbieSpacing.m)
            }
            .background(palette.bg.ignoresSafeArea())
            .navigationTitle(viewModel.screenTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "common.action.cancel")) {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            viewModel.configure(environment, request: request)
        }
        .onChange(of: photo) { _, item in
            Task { await loadPhoto(item) }
        }
    }

    private var linkField: some View {
        FieldRow(
            label: String(localized: "wishes.editor.link"),
            hint: linkHint
        ) {
            VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                TextField(String(localized: "wishes.editor.link.placeholder"), text: $viewModel.link)
                    .textFieldStyle(.plain)
                    .textContentType(.URL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .corbieBody()
                    .foregroundStyle(palette.text)
                    .modifier(WishFieldBox())
                    .accessibilityLabel(Text("wishes.editor.link"))
                    .onChange(of: viewModel.link) { _, _ in
                        viewModel.linkChanged()
                    }
                if viewModel.parseState == .parsing {
                    WishParseSkeleton()
                }
            }
        }
    }

    private var linkHint: String {
        switch viewModel.parseState {
        case .idle: return String(localized: "wishes.editor.link.hint")
        case .parsing: return String(localized: "wishes.editor.link.reading")
        case .failed: return String(localized: "wishes.editor.link.failed")
        }
    }

    private var photoField: some View {
        FieldRow(label: String(localized: "wishes.editor.photo")) {
            HStack(spacing: CorbieSpacing.s) {
                WishThumbnail(localImage: viewModel.localImage, imageURL: viewModel.imageURL)
                VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                    PhotosPicker(selection: $photo, matching: .images, photoLibrary: .shared()) {
                        Text("wishes.editor.photo.pick")
                            .corbieMono()
                            .foregroundStyle(palette.accent)
                            .frame(minHeight: CorbieMetrics.minimumTapTarget, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    if viewModel.localImage != nil {
                        Button {
                            photo = nil
                            viewModel.setPhoto(nil)
                        } label: {
                            Text("wishes.editor.photo.remove")
                                .corbieMono()
                                .foregroundStyle(palette.text2)
                                .frame(minHeight: CorbieMetrics.minimumTapTarget, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var priceField: some View {
        FieldRow(label: String(localized: "wishes.editor.price")) {
            HStack(spacing: CorbieSpacing.s) {
                TextField(String(localized: "wishes.editor.price.placeholder"), text: $viewModel.priceText)
                    .textFieldStyle(.plain)
                    .keyboardType(.decimalPad)
                    .corbieBody()
                    .foregroundStyle(palette.text)
                    .modifier(WishFieldBox())
                    .accessibilityLabel(Text("wishes.editor.price"))
                Menu {
                    Picker(String(localized: "wishes.editor.currency"), selection: $viewModel.currency) {
                        ForEach(viewModel.currencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                } label: {
                    Text(viewModel.currency)
                        .corbieMono()
                        .foregroundStyle(palette.text)
                        .frame(minWidth: CorbieSpacing.xxl)
                        .modifier(WishFieldBox())
                }
                .accessibilityLabel(Text("wishes.editor.currency"))
            }
        }
    }

    private var priorityField: some View {
        FieldRow(label: String(localized: "wishes.editor.priority")) {
            SegmentedPicker(selection: $viewModel.priority, options: WishPriority.allCases) { priority in
                priority.title
            }
        }
    }

    private var ownerToggle: some View {
        Toggle(isOn: $viewModel.isForMe) {
            VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                Text("wishes.editor.forme")
                    .corbieBody()
                    .foregroundStyle(palette.text)
                Text("wishes.editor.forme.hint")
                    .corbieMono()
                    .foregroundStyle(palette.text2)
            }
        }
        .tint(palette.accent)
        .frame(minHeight: CorbieMetrics.minimumTapTarget)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            environment.report(CorbieError.invalidInput("this photo could not be read"))
            return
        }
        viewModel.setPhoto(data)
    }

    private func save() async {
        guard await viewModel.save() else { return }
        await onSaved()
        dismiss()
    }
}

struct WishFieldBox: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, CorbieSpacing.s)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
            .corbieFieldBox()
    }
}

struct WishParseSkeleton: View {
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: CorbieSpacing.s) {
            RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
                .fill(palette.elevated)
                .frame(width: WishThumbnail.side, height: WishThumbnail.side)
            VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
                    .fill(palette.elevated)
                    .frame(height: CorbieSpacing.m)
                RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
                    .fill(palette.elevated)
                    .frame(width: CorbieMetrics.controlHeight * 2, height: CorbieSpacing.s)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text("wishes.editor.link.reading"))
    }
}

#if DEBUG
#Preview {
    WishEditorView(request: WishEditorRequest(wish: nil, link: nil)) {}
        .environment(AppEnvironment.preview())
}
#endif
