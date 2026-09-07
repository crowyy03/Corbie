import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainChoreSplitEngineTests {
    private let memberA = UUID(uuidString: "11111111-1111-4111-8111-111111111111") ?? UUID()
    private let memberB = UUID(uuidString: "22222222-2222-4222-8222-222222222222") ?? UUID()

    private func candidate(
        _ number: Int,
        _ frequency: ChoreFrequency,
        _ verdictA: ChoreVerdict,
        _ verdictB: ChoreVerdict
    ) -> ChoreSplitCandidate {
        ChoreSplitCandidate(
            id: UUID(uuidString: String(format: "33333333-3333-4333-8333-%012d", number)) ?? UUID(),
            loadPerWeek: frequency.loadPerWeek,
            verdictA: verdictA,
            verdictB: verdictB
        )
    }

    private func split(_ candidates: [ChoreSplitCandidate]) -> ChoreSplitOutcome {
        ChoreSplitEngine.split(candidates, memberAId: memberA, memberBId: memberB)
    }

    private func load(_ outcome: ChoreSplitOutcome, _ candidates: [ChoreSplitCandidate], of member: UUID) -> Double {
        candidates.reduce(0) { total, candidate in
            guard let decision = outcome.decision(for: candidate.id) else { return total }
            switch decision.result {
            case .member:
                return decision.assignedMemberId == member ? total + candidate.loadPerWeek : total
            case .rotate, .anyone:
                return total + candidate.loadPerWeek / 2
            }
        }
    }

    @Test func whatBothOfYouHateRotates() throws {
        let candidates = [
            candidate(1, .weekly, .hate, .hate),
            candidate(2, .weekly, .like, .hate),
            candidate(3, .weekly, .hate, .like)
        ]
        let outcome = split(candidates)
        let hated = try #require(outcome.decision(for: candidates[0].id))
        #expect(hated.result == .rotate)
        #expect(hated.assignedMemberId == nil)
    }

    @Test func theBiggestDisagreementBecomesATrade() throws {
        let candidates = [
            candidate(1, .weekly, .like, .hate),
            candidate(2, .weekly, .hate, .like),
            candidate(3, .weekly, .fine, .neutral),
            candidate(4, .weekly, .neutral, .fine)
        ]
        let outcome = split(candidates)
        let mine = try #require(outcome.decision(for: candidates[0].id))
        let theirs = try #require(outcome.decision(for: candidates[1].id))
        #expect(mine.assignedMemberId == memberA)
        #expect(theirs.assignedMemberId == memberB)
        #expect(mine.scoreA == 2)
        #expect(mine.scoreB == -2)
    }

    @Test func identicalRatingsAreSplitByHowOftenAChoreComesUp() {
        let candidates = [
            candidate(1, .daily, .fine, .fine),
            candidate(2, .fewTimesAWeek, .fine, .fine),
            candidate(3, .fewTimesAWeek, .fine, .fine),
            candidate(4, .weekly, .fine, .fine),
            candidate(5, .weekly, .fine, .fine),
            candidate(6, .monthly, .fine, .fine),
            candidate(7, .monthly, .fine, .fine),
            candidate(8, .quarterly, .fine, .fine)
        ]
        let outcome = split(candidates)
        #expect(outcome.isBalanced)
        #expect(load(outcome, candidates, of: memberA) > 0)
        #expect(load(outcome, candidates, of: memberB) > 0)
    }

    @Test func theLoadNeverEndsMoreThanFifteenPercentApart() {
        let frequencies: [ChoreFrequency] = [
            .daily, .daily, .fewTimesAWeek, .fewTimesAWeek, .weekly, .weekly, .weekly,
            .everyTwoWeeks, .everyTwoWeeks, .monthly, .monthly, .quarterly
        ]
        let verdicts: [(ChoreVerdict, ChoreVerdict)] = [
            (.like, .hate), (.hate, .like), (.fine, .fine), (.neutral, .hate), (.like, .like),
            (.hate, .hate), (.fine, .neutral), (.neutral, .neutral), (.like, .fine), (.hate, .fine),
            (.fine, .like), (.neutral, .like)
        ]
        let candidates = (0..<frequencies.count).map { index in
            candidate(index + 1, frequencies[index], verdicts[index].0, verdicts[index].1)
        }
        let outcome = split(candidates)
        let loadA = load(outcome, candidates, of: memberA)
        let loadB = load(outcome, candidates, of: memberB)
        #expect(abs(loadA - loadB) <= outcome.totalLoad * ChoreSplitEngine.balanceTolerance + 0.000_001)
        #expect(outcome.decisions.count == candidates.count)
    }

    @Test func oneHeavyChoreDoesNotDragTheRestWithIt() throws {
        var candidates = [candidate(1, .daily, .like, .hate)]
        candidates += (2...12).map { candidate($0, .weekly, .like, .hate) }
        let outcome = split(candidates)
        let heavy = try #require(outcome.decision(for: candidates[0].id))
        #expect(heavy.assignedMemberId == memberA)
        let loadA = load(outcome, candidates, of: memberA)
        let loadB = load(outcome, candidates, of: memberB)
        #expect(abs(loadA - loadB) <= outcome.totalLoad * ChoreSplitEngine.balanceTolerance + 0.000_001)
        #expect(loadB > 0)
    }

    @Test func whatBothOfYouLikeIsLeftToWhoeverIsAround() throws {
        let candidates = [
            candidate(1, .weekly, .like, .hate),
            candidate(2, .weekly, .hate, .like),
            candidate(3, .weekly, .like, .like)
        ]
        let outcome = split(candidates)
        let shared = try #require(outcome.decision(for: candidates[2].id))
        #expect(shared.result == .anyone)
        #expect(shared.assignedMemberId == nil)
    }

    @Test func theSameRatingsAlwaysGiveTheSameSplit() {
        let candidates = (1...10).map { index in
            candidate(index, index.isMultiple(of: 3) ? .daily : .weekly, .fine, index.isMultiple(of: 2) ? .hate : .like)
        }
        #expect(split(candidates) == split(candidates))
        #expect(split(candidates) == split(candidates.reversed()))
    }

    @Test func aSplitThatCannotBalanceStopsInsteadOfSwappingForever() throws {
        let candidates = [
            candidate(1, .daily, .like, .hate),
            candidate(2, .weekly, .like, .hate)
        ]
        let outcome = split(candidates)
        let heavy = try #require(outcome.decision(for: candidates[0].id))
        let light = try #require(outcome.decision(for: candidates[1].id))
        #expect(heavy.assignedMemberId == memberA)
        #expect(light.assignedMemberId == memberB)
        #expect(outcome.isBalanced == false)
    }

    @Test func anEmptyListSplitsIntoNothing() {
        let outcome = split([])
        #expect(outcome.decisions.isEmpty)
        #expect(outcome.totalLoad == 0)
        #expect(outcome.isBalanced)
    }
}
