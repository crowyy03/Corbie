import CorbieCore
import SafariServices
import SwiftUI

enum PaywallLink: String, Identifiable, CaseIterable {
    case privacy = "https://corbie.app/privacy"
    case terms = "https://corbie.app/terms"

    var id: String { rawValue }

    var url: URL? { URL(string: rawValue) }

    var titleKey: String {
        switch self {
        case .privacy: return "paywall.link.privacy"
        case .terms: return "paywall.link.terms"
        }
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.preferredControlTintColor = UIColor(CorbieColorPalette.ice)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
