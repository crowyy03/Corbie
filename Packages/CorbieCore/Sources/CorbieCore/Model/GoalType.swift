import Foundation

public enum GoalType: String, Codable, Sendable, CaseIterable {
    case trip
    case purchase
    case renovation
    case event
    case other
}
