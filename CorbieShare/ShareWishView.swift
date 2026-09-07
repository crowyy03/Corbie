import CorbieCore
import SwiftUI

struct ShareWishView: View {
    @Environment(\.palette) private var palette

    let items: [NSExtensionItem]
    let onFinish: () -> Void

    @State private var viewModel = ShareWishViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    header
                    switch viewModel.stage {
                    case .loading:
                        Text("share.stage.loading")
                            .corbieMono()
                            .foregroundStyle(palette.text2)
                    case .noSession:
                        Text("share.stage.nosession")
                            .corbieBody()
                            .foregroundStyle(palette.text)
                    case .readOnly:
                        Text("share.stage.readonly")
                            .corbieBody()
                            .foregroundStyle(palette.text)
                    case .ready:
                        form
                    }
                    Spacer(minLength: 0)
                }
                .padding(CorbieSpacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(palette.bg.ignoresSafeArea())
            .navigationTitle(String(localized: "share.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "share.action.cancel"), action: onFinish)
                }
            }
        }
        .task {
            let input = await ShareAttachments.read(items)
            await viewModel.start(input)
        }
    }

    @ViewBuilder
    private var header: some View {
        if let link = viewModel.link {
            Text(link.absoluteString)
                .corbieMono()
                .foregroundStyle(palette.text2)
                .lineLimit(2)
                .truncationMode(.middle)
        } else if viewModel.hasNothingShared {
            Text("share.preview.empty")
                .corbieMono()
                .foregroundStyle(palette.text2)
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.l) {
            if viewModel.isParsing {
                Text("share.stage.parsing")
                    .corbieMono()
                    .foregroundStyle(palette.text2)
            } else if viewModel.didParseFail {
                Text("share.stage.parsefailed")
                    .corbieMono()
                    .foregroundStyle(palette.text2)
            }
            TextFieldRow(
                label: String(localized: "wishes.editor.name"),
                placeholder: String(localized: "wishes.editor.name.placeholder"),
                text: $viewModel.title
            )
            FieldRow(label: String(localized: "wishes.editor.priority")) {
                SegmentedPicker(selection: $viewModel.priority, options: WishPriority.allCases) { priority in
                    priority.title
                }
            }
            Toggle(isOn: $viewModel.isForMe) {
                Text("wishes.editor.forme")
                    .corbieBody()
                    .foregroundStyle(palette.text)
            }
            .tint(palette.accent)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
            if viewModel.didSaveFail {
                Text("share.stage.savefailed")
                    .corbieMono()
                    .foregroundStyle(palette.warn)
            }
            PrimaryButton(title: String(localized: "share.action.save")) {
                Task {
                    if await viewModel.save() { onFinish() }
                }
            }
            .disabled(viewModel.canSave == false)
        }
    }
}

#if DEBUG
#Preview {
    ShareWishView(items: [], onFinish: {})
}
#endif
