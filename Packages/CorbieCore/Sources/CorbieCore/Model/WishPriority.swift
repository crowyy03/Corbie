import Foundation

public enum WishPriority: String, Codable, Sendable, CaseIterable {
    case must
    case want
    case someday

    public var title: String {
        switch self {
        case .must: return String(localized: "wishes.priority.must")
        case .want: return String(localized: "wishes.priority.want")
        case .someday: return String(localized: "wishes.priority.someday")
        }
    }
}

public enum WishText {
    public static func clean(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
