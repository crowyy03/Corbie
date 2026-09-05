import Observation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
@Observable
final class SharePayload {
    var url: URL?
    var text: String?
}

@MainActor
final class ShareViewController: UIViewController {
    private let payload = SharePayload()

    override func viewDidLoad() {
        super.viewDidLoad()
        embedShareView()
        loadAttachment()
    }

    private func embedShareView() {
        let hosting = UIHostingController(
            rootView: ShareRootView(payload: payload) { [weak self] in
                self?.completeRequest()
            }
        )
        addChild(hosting)
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        hosting.didMove(toParent: self)
    }

    private func loadAttachment() {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }

        if let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                let url = item as? URL
                Task { @MainActor [weak self] in
                    self?.payload.url = url
                }
            }
            return
        }

        if let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        }) {
            provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { item, _ in
                let text = item as? String
                Task { @MainActor [weak self] in
                    self?.payload.text = text
                }
            }
        }
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}

struct ShareRootView: View {
    let payload: SharePayload
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                sharedContent
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationTitle(String(localized: "share.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(String(localized: "share.action.cancel"), action: onCancel)
                }
            }
        }
    }

    @ViewBuilder
    private var sharedContent: some View {
        if let url = payload.url {
            Text(url.absoluteString)
                .font(.footnote)
                .fontDesign(.monospaced)
                .lineLimit(4)
        } else if let text = payload.text, !text.isEmpty {
            Text(text)
                .font(.body)
                .lineLimit(8)
        } else {
            Text("share.preview.empty")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ShareRootView(payload: SharePayload(), onCancel: {})
}
