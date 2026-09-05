import Foundation

public enum EventKind: String, Codable, Sendable, CaseIterable {
    case event
    case birthday
    case anniversary
    case trip
}
