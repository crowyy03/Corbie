import CorbieCore
import SafariServices
import SwiftUI

enum LegalPage: String, Identifiable, CaseIterable {
    case privacy
    case terms

    var id: String { rawValue }

    var url: URL? { URL(string: "https://corbie.app/" + rawValue) }

    var settingsTitleKey: String { "settings.legal." + rawValue }

    var paywallTitleKey: String { "paywall.link." + rawValue }
}

struct LegalPageView: UIViewControllerRepresentable {
    @Environment(\.palette) private var palette

    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.preferredControlTintColor = UIColor(palette.accent)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
