import CorbieCore
import Foundation

enum InviteLink {
    static func url(code: String) -> URL? {
        let sanitized = InviteCodeFormat.sanitize(code)
        guard sanitized.isEmpty == false else { return nil }
        return URL(string: "https://\(CorbieIdentifiers.universalLinkHost)/join/\(sanitized)")
    }

    static func message(code: String) -> String {
        guard let url = url(code: code) else { return "" }
        return String(format: String(localized: "pairing.invite.share.message"), url.absoluteString)
    }
}
