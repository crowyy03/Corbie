import CorbieCore
import Foundation

enum VoteOutcome: Equatable {
    case needsYourAnswer
    case waitingForPartner
    case match([Int])
    case mismatch(yours: [Int], theirs: [Int])
    case noMatch(yours: [Int])

    static func make(vote: VoteDTO, viewerMemberId: UUID?, partnerMemberId: UUID?) -> VoteOutcome {
        guard let viewerMemberId, let yours = vote.responses[viewerMemberId] else { return .needsYourAnswer }
        guard vote.canSeeResults(as: viewerMemberId),
              let partnerMemberId,
              partnerMemberId != viewerMemberId,
              let theirs = vote.responses[partnerMemberId]
        else { return .waitingForPartner }
        let matches = vote.matchingOptions
        if matches.isEmpty == false { return .match(matches) }
        return vote.mode == .single ? .mismatch(yours: yours, theirs: theirs) : .noMatch(yours: yours)
    }

    var showsResults: Bool {
        switch self {
        case .needsYourAnswer, .waitingForPartner: return false
        case .match, .mismatch, .noMatch: return true
        }
    }

    func partnerVisibleOptions() -> [Int] {
        switch self {
        case let .match(options): return options
        case let .mismatch(_, theirs): return theirs
        case .needsYourAnswer, .waitingForPartner, .noMatch: return []
        }
    }
}
