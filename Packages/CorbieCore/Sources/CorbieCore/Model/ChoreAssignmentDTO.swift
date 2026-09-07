import Foundation

public struct ChoreAssignmentDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var choreItemId: UUID?
    public var result: ChoreAssignmentResult
    public var assignedMemberId: UUID?
    public var memberAId: UUID?
    public var memberBId: UUID?
    public var scoreA: Int
    public var scoreB: Int
    public var createdAt: Date?

    public init(
        id: UUID,
        choreItemId: UUID? = nil,
        result: ChoreAssignmentResult = .anyone,
        assignedMemberId: UUID? = nil,
        memberAId: UUID? = nil,
        memberBId: UUID? = nil,
        scoreA: Int = 0,
        scoreB: Int = 0,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.choreItemId = choreItemId
        self.result = result
        self.assignedMemberId = assignedMemberId
        self.memberAId = memberAId
        self.memberBId = memberBId
        self.scoreA = scoreA
        self.scoreB = scoreB
        self.createdAt = createdAt
    }

    public init(_ assignment: ChoreAssignment) {
        self.init(
            id: assignment.id ?? UUID(),
            choreItemId: assignment.choreItem?.id,
            result: assignment.result,
            assignedMemberId: assignment.assignedMemberId,
            memberAId: assignment.memberAId,
            memberBId: assignment.memberBId,
            scoreA: Int(assignment.scoreA),
            scoreB: Int(assignment.scoreB),
            createdAt: assignment.createdAt
        )
    }

    public func score(for memberId: UUID?) -> Int? {
        guard let memberId else { return nil }
        if memberId == memberAId { return scoreA }
        if memberId == memberBId { return scoreB }
        return nil
    }

    public var scoreGap: Int { abs(scoreA - scoreB) }
}
