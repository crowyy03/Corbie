import Foundation

enum InviteCodeFormat {
    static let alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
    static let length = 6

    static func sanitize(_ raw: String) -> String {
        let allowed = Set(alphabet)
        var result = ""
        for character in raw.uppercased() where allowed.contains(character) {
            result.append(character)
            if result.count == length { break }
        }
        return result
    }

    static func isComplete(_ raw: String) -> Bool {
        sanitize(raw).count == length
    }

    static func spelledOut(_ raw: String) -> String {
        sanitize(raw).map(String.init).joined(separator: " ")
    }
}
