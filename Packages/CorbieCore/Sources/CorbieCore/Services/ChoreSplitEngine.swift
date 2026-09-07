import Foundation

public struct ChoreSplitCandidate: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let loadPerWeek: Double
    public let verdictA: ChoreVerdict
    public let verdictB: ChoreVerdict

    public init(id: UUID, loadPerWeek: Double, verdictA: ChoreVerdict, verdictB: ChoreVerdict) {
        self.id = id
        self.loadPerWeek = loadPerWeek
        self.verdictA = verdictA
        self.verdictB = verdictB
    }

    public var scoreA: Int { verdictA.weight }

    public var scoreB: Int { verdictB.weight }

    public var scoreGap: Int { abs(scoreA - scoreB) }
}

public struct ChoreSplitDecision: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let result: ChoreAssignmentResult
    public let assignedMemberId: UUID?
    public let scoreA: Int
    public let scoreB: Int

    public init(id: UUID, result: ChoreAssignmentResult, assignedMemberId: UUID?, scoreA: Int, scoreB: Int) {
        self.id = id
        self.result = result
        self.assignedMemberId = assignedMemberId
        self.scoreA = scoreA
        self.scoreB = scoreB
    }
}

public struct ChoreSplitOutcome: Sendable, Equatable {
    public let decisions: [ChoreSplitDecision]
    public let totalLoad: Double
    public let balanceGap: Double

    public init(decisions: [ChoreSplitDecision], totalLoad: Double, balanceGap: Double) {
        self.decisions = decisions
        self.totalLoad = totalLoad
        self.balanceGap = balanceGap
    }

    public var isBalanced: Bool { balanceGap <= totalLoad * ChoreSplitEngine.balanceTolerance }

    public func decision(for itemId: UUID) -> ChoreSplitDecision? {
        decisions.first { $0.id == itemId }
    }
}

public enum ChoreSplitEngine {
    public static let balanceTolerance = 0.15

    public static func split(
        _ candidates: [ChoreSplitCandidate],
        memberAId: UUID,
        memberBId: UUID
    ) -> ChoreSplitOutcome {
        var run = SplitRun(candidates: candidates, memberAId: memberAId, memberBId: memberBId)
        run.shareUnwanted()
        run.holdMutuallyLiked()
        run.assignContested()
        run.assignHeld()
        run.spendLikedOnBalance()
        run.rebalance()
        return run.outcome()
    }
}

private struct SplitRun {
    private let candidates: [ChoreSplitCandidate]
    private let memberAId: UUID
    private let memberBId: UUID
    private let totalLoad: Double
    private let cap: Double

    private var results: [UUID: ChoreAssignmentResult] = [:]
    private var owners: [UUID: UUID] = [:]
    private var held: [ChoreSplitCandidate] = []
    private var liked: [ChoreSplitCandidate] = []
    private var loadA: Double = 0
    private var loadB: Double = 0

    init(candidates: [ChoreSplitCandidate], memberAId: UUID, memberBId: UUID) {
        self.candidates = candidates.sorted { $0.id.uuidString < $1.id.uuidString }
        self.memberAId = memberAId
        self.memberBId = memberBId
        totalLoad = candidates.reduce(0) { $0 + $1.loadPerWeek }
        let heaviest = candidates.map(\.loadPerWeek).max() ?? 0
        cap = totalLoad / 2 + heaviest
    }

    mutating func shareUnwanted() {
        for candidate in candidates where candidate.verdictA == .hate && candidate.verdictB == .hate {
            results[candidate.id] = .rotate
            share(candidate)
        }
    }

    mutating func holdMutuallyLiked() {
        for candidate in candidates where results[candidate.id] == nil {
            guard candidate.scoreA == candidate.scoreB else { continue }
            if candidate.verdictA == .like && candidate.verdictB == .like {
                liked.append(candidate)
                share(candidate)
            } else {
                held.append(candidate)
            }
        }
    }

    mutating func assignContested() {
        let contested = candidates
            .filter { results[$0.id] == nil && held.contains($0) == false && liked.contains($0) == false }
            .sorted { left, right in
                if left.scoreGap != right.scoreGap { return left.scoreGap > right.scoreGap }
                if left.loadPerWeek != right.loadPerWeek { return left.loadPerWeek > right.loadPerWeek }
                return left.id.uuidString < right.id.uuidString
            }
        for candidate in contested {
            let winner = candidate.scoreA > candidate.scoreB ? memberAId : memberBId
            if load(of: winner) + candidate.loadPerWeek <= cap {
                assign(candidate, to: winner)
            } else {
                held.append(candidate)
            }
        }
    }

    mutating func assignHeld() {
        let ordered = held.sorted { left, right in
            if left.loadPerWeek != right.loadPerWeek { return left.loadPerWeek > right.loadPerWeek }
            return left.id.uuidString < right.id.uuidString
        }
        held = []
        for candidate in ordered {
            assign(candidate, to: lighterMemberId)
        }
    }

    mutating func spendLikedOnBalance() {
        let ordered = liked.sorted { left, right in
            if left.loadPerWeek != right.loadPerWeek { return left.loadPerWeek > right.loadPerWeek }
            return left.id.uuidString < right.id.uuidString
        }
        for candidate in ordered where isBalanced == false {
            let target = lighterMemberId
            let projected = projectedGap(moving: candidate.loadPerWeek, to: target)
            guard projected < gap else { continue }
            liked.removeAll { $0.id == candidate.id }
            unshare(candidate)
            assign(candidate, to: target)
        }
        for candidate in liked {
            results[candidate.id] = .anyone
        }
    }

    mutating func rebalance() {
        while isBalanced == false {
            let heavier = loadA > loadB ? memberAId : memberBId
            let lighter = heavier == memberAId ? memberBId : memberAId
            let movable = candidates
                .filter { owners[$0.id] == heavier }
                .sorted { left, right in
                    if left.scoreGap != right.scoreGap { return left.scoreGap < right.scoreGap }
                    if left.loadPerWeek != right.loadPerWeek { return left.loadPerWeek < right.loadPerWeek }
                    return left.id.uuidString < right.id.uuidString
                }
            guard let move = movable.first(where: { abs(gap - $0.loadPerWeek * 2) < gap }) else { return }
            withdraw(move, from: heavier)
            assign(move, to: lighter)
        }
    }

    func outcome() -> ChoreSplitOutcome {
        let decisions = candidates.map { candidate in
            ChoreSplitDecision(
                id: candidate.id,
                result: results[candidate.id] ?? .anyone,
                assignedMemberId: owners[candidate.id],
                scoreA: candidate.scoreA,
                scoreB: candidate.scoreB
            )
        }
        return ChoreSplitOutcome(decisions: decisions, totalLoad: totalLoad, balanceGap: gap)
    }

    private var gap: Double { abs(loadA - loadB) }

    private var isBalanced: Bool { gap <= totalLoad * ChoreSplitEngine.balanceTolerance }

    private var lighterMemberId: UUID { loadA <= loadB ? memberAId : memberBId }

    private func load(of memberId: UUID) -> Double { memberId == memberAId ? loadA : loadB }

    private func projectedGap(moving load: Double, to memberId: UUID) -> Double {
        memberId == memberAId ? abs(loadA + load - loadB) : abs(loadA - loadB - load)
    }

    private mutating func share(_ candidate: ChoreSplitCandidate) {
        loadA += candidate.loadPerWeek / 2
        loadB += candidate.loadPerWeek / 2
    }

    private mutating func unshare(_ candidate: ChoreSplitCandidate) {
        loadA -= candidate.loadPerWeek / 2
        loadB -= candidate.loadPerWeek / 2
    }

    private mutating func assign(_ candidate: ChoreSplitCandidate, to memberId: UUID) {
        results[candidate.id] = .member
        owners[candidate.id] = memberId
        if memberId == memberAId {
            loadA += candidate.loadPerWeek
        } else {
            loadB += candidate.loadPerWeek
        }
    }

    private mutating func withdraw(_ candidate: ChoreSplitCandidate, from memberId: UUID) {
        owners[candidate.id] = nil
        results[candidate.id] = nil
        if memberId == memberAId {
            loadA -= candidate.loadPerWeek
        } else {
            loadB -= candidate.loadPerWeek
        }
    }
}
