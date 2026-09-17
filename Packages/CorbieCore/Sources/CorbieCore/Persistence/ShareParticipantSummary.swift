import Foundation

public struct ShareParticipantSummary: Sendable, Equatable {
    public enum Acceptance: Sendable, Equatable {
        case accepted
        case pending
        case removed
        case unknown
    }

    public let isOwner: Bool
    public let acceptance: Acceptance

    public init(isOwner: Bool, acceptance: Acceptance) {
        self.isOwner = isOwner
        self.acceptance = acceptance
    }
}
