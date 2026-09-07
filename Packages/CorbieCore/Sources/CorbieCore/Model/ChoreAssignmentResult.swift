import Foundation

public enum ChoreAssignmentResult: String, Sendable, Equatable, CaseIterable, Codable {
    case member
    case rotate
    case anyone

    public var isShared: Bool { self != .member }
}
