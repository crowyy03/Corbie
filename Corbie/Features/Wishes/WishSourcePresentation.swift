import CorbieCore
import Foundation

extension WishSource {
    var brandName: String? {
        switch self {
        case .amazon: return "Amazon"
        case .target: return "Target"
        case .etsy: return "Etsy"
        case .sephora: return "Sephora"
        case .nordstrom: return "Nordstrom"
        case .zara: return "Zara"
        case .ikea: return "IKEA"
        case .instagram: return "Instagram"
        case .tiktok: return "TikTok"
        case .store, .manual: return nil
        }
    }

    func tag(url: String?) -> String? {
        if let brandName { return brandName }
        if let host = WishSource.host(of: url) { return host }
        return self == .store ? String(localized: "wishes.source.link") : nil
    }

    static func host(of url: String?) -> String? {
        guard let url, let host = URL(string: url)?.host() else { return nil }
        let bare = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return bare.isEmpty ? nil : bare
    }
}
