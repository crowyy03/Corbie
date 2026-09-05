import Foundation

public enum PlanStatus: String, Codable, Sendable, CaseIterable {
    case active
    case completed
    case archived
}
