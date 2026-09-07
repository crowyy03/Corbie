import Foundation

public enum ChoreSetStatus: String, Sendable, Equatable, CaseIterable, Codable {
    case building
    case rating
    case revealed
    case applied
}
