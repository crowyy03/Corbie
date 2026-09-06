import SafariServices
import SwiftUI

enum SettingsLegalPage: String, Identifiable, CaseIterable {
    case privacy
    case terms

    var id: String { rawValue }

    var titleKey: String { "settings.legal." + rawValue }

    var url: URL? {
        switch self {
        case .privacy: return URL(string: "https://corbie.app/privacy")
        case .terms: return URL(string: "https://corbie.app/terms")
        }
    }
}

struct SettingsLegalView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) { }
}
