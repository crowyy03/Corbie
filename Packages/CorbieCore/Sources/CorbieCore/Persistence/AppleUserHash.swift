import CryptoKit
import Foundation

public enum AppleUserHash {
    public static func value(_ appleUserId: String) -> String {
        SHA256.hash(data: Data(appleUserId.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
