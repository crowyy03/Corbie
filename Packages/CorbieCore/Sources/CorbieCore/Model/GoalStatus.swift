import Foundation

public enum GoalStatus: String, Codable, Sendable, CaseIterable {
    case active
    case completed
    case archived
}
