import Foundation

public enum WishPriority: String, Codable, Sendable, CaseIterable {
    case must
    case want
    case someday
}
