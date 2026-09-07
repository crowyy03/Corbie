import Foundation

public enum ChoreVerdict: String, Sendable, Equatable, CaseIterable, Codable {
    case hate
    case neutral
    case fine
    case like

    public var weight: Int {
        switch self {
        case .hate: return -2
        case .neutral: return 0
        case .fine: return 1
        case .like: return 2
        }
    }
}
