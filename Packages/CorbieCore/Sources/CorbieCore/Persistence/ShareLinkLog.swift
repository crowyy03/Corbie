import CryptoKit
import Foundation

public enum ShareLinkLog {
    public static func text(for url: URL) -> String {
        #if DEBUG
        return url.absoluteString
        #else
        return "\(url.host() ?? "no-host") #\(fingerprint(of: url))"
        #endif
    }

    public static func fingerprint(of url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
    }
}
