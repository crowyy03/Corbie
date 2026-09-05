import CorbieCore
import XCTest
@testable import Corbie

final class VotesOutcomeTests: XCTestCase {
    private let viewer = UUID()
    private let partner = UUID()
    private let revealedAt = Date(timeIntervalSince1970: 1_757_000_000)

    func testAnUnansweredVoteAsksTheViewerFirst() {
        let vote = makeVote(mode: .single, answers: [partner: [1]])
        XCTAssertEqual(outcome(vote), .needsYourAnswer)
    }

    func testTheirAnswerStaysHiddenUntilBothHaveAnswered() {
        let vote = makeVote(mode: .single, answers: [viewer: [0]])
        XCTAssertEqual(outcome(vote), .waitingForPartner)
        XCTAssertTrue(outcome(vote).partnerVisibleOptions().isEmpty)
    }

    func testRevealOffStillHidesAPartnerWhoHasNotAnswered() {
        let vote = makeVote(mode: .single, answers: [viewer: [0]], revealWhenBothAnswered: false)
        XCTAssertEqual(outcome(vote), .waitingForPartner)
    }

    func testSingleModeMatchAndMismatch() {
        let matched = makeVote(mode: .single, answers: [viewer: [2], partner: [2]], revealed: true)
        XCTAssertEqual(outcome(matched), .match([2]))
        XCTAssertEqual(outcome(matched).partnerVisibleOptions(), [2])

        let missed = makeVote(mode: .single, answers: [viewer: [0], partner: [2]], revealed: true)
        XCTAssertEqual(outcome(missed), .mismatch(yours: [0], theirs: [2]))
        XCTAssertEqual(outcome(missed).partnerVisibleOptions(), [2])
    }

    func testMultiModeShowsOnlyTheOverlap() {
        let overlapping = makeVote(
            mode: .multi,
            answers: [viewer: [0, 1], partner: [1, 2]],
            revealed: true
        )
        XCTAssertEqual(outcome(overlapping), .match([1]))
        XCTAssertEqual(outcome(overlapping).partnerVisibleOptions(), [1])

        let apart = makeVote(mode: .multi, answers: [viewer: [0], partner: [1, 2]], revealed: true)
        XCTAssertEqual(outcome(apart), .noMatch(yours: [0]))
        XCTAssertTrue(outcome(apart).partnerVisibleOptions().isEmpty)
    }

    func testResultsNeedAKnownPartner() {
        let vote = makeVote(mode: .single, answers: [viewer: [0], partner: [0]], revealed: true)
        XCTAssertEqual(VoteOutcome.make(vote: vote, viewerMemberId: viewer, partnerMemberId: nil), .waitingForPartner)
        XCTAssertEqual(VoteOutcome.make(vote: vote, viewerMemberId: viewer, partnerMemberId: viewer), .waitingForPartner)
        XCTAssertEqual(VoteOutcome.make(vote: vote, viewerMemberId: nil, partnerMemberId: partner), .needsYourAnswer)
    }

    private func outcome(_ vote: VoteDTO) -> VoteOutcome {
        VoteOutcome.make(vote: vote, viewerMemberId: viewer, partnerMemberId: partner)
    }

    private func makeVote(
        mode: VoteMode,
        answers: [UUID: [Int]],
        revealWhenBothAnswered: Bool = true,
        revealed: Bool = false
    ) -> VoteDTO {
        var byMember: [String: [Int]] = [:]
        for (memberId, options) in answers {
            byMember[memberId.uuidString] = options
        }
        return VoteDTO(
            id: UUID(),
            question: "Where do we eat",
            options: ["Out", "Delivery", "Cook at home"],
            mode: mode,
            responses: VoteResponses(byMember: byMember),
            revealWhenBothAnswered: revealWhenBothAnswered,
            revealedAt: revealed ? revealedAt : nil
        )
    }
}
