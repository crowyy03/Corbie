import Foundation

public struct PlanStepDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var planId: UUID?
    public var planTitle: String
    public var title: String
    public var note: String?
    public var isDone: Bool
    public var doneByMemberId: UUID?
    public var doneAt: Date?
    public var assigneeMemberId: UUID?
    public var dueAt: Date?
    public var sortIndex: Int
    public var createdAt: Date?

    public init(
        id: UUID,
        planId: UUID? = nil,
        planTitle: String = "",
        title: String = "",
        note: String? = nil,
        isDone: Bool = false,
        doneByMemberId: UUID? = nil,
        doneAt: Date? = nil,
        assigneeMemberId: UUID? = nil,
        dueAt: Date? = nil,
        sortIndex: Int = 0,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.planId = planId
        self.planTitle = planTitle
        self.title = title
        self.note = note
        self.isDone = isDone
        self.doneByMemberId = doneByMemberId
        self.doneAt = doneAt
        self.assigneeMemberId = assigneeMemberId
        self.dueAt = dueAt
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }

    public init(_ step: PlanStep) {
        self.init(
            id: step.id ?? UUID(),
            planId: step.plan?.id,
            planTitle: step.plan?.title ?? "",
            title: step.title ?? "",
            note: step.note,
            isDone: step.isDone,
            doneByMemberId: step.doneByMemberId,
            doneAt: step.doneAt,
            assigneeMemberId: step.assigneeMemberId,
            dueAt: step.dueAt,
            sortIndex: Int(step.sortIndex),
            createdAt: step.createdAt
        )
    }

    public var hasDue: Bool { dueAt != nil }

    public static func checklistOrder(_ lhs: PlanStepDTO, _ rhs: PlanStepDTO) -> Bool {
        if lhs.isDone != rhs.isDone { return rhs.isDone }
        if lhs.sortIndex != rhs.sortIndex { return lhs.sortIndex < rhs.sortIndex }
        return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
    }
}
