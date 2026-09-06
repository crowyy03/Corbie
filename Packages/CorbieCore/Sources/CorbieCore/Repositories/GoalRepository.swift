import Foundation

public struct GoalDraft: Sendable, Equatable {
    public var spaceId: UUID
    public var title: String
    public var type: GoalType
    public var targetAmount: Double
    public var currency: String
    public var savedAmount: Double
    public var startAt: Date?
    public var endAt: Date?
    public var note: String?
    public var createdByMemberId: UUID?

    public init(
        spaceId: UUID,
        title: String,
        type: GoalType = .other,
        targetAmount: Double = 0,
        currency: String = "USD",
        savedAmount: Double = 0,
        startAt: Date? = nil,
        endAt: Date? = nil,
        note: String? = nil,
        createdByMemberId: UUID? = nil
    ) {
        self.spaceId = spaceId
        self.title = title
        self.type = type
        self.targetAmount = targetAmount
        self.currency = currency
        self.savedAmount = savedAmount
        self.startAt = startAt
        self.endAt = endAt
        self.note = note
        self.createdByMemberId = createdByMemberId
    }
}

public struct GoalExpenseDraft: Sendable, Equatable {
    public var amount: Double
    public var currency: String
    public var fxRateToGoalCurrency: Double
    public var note: String?
    public var date: Date
    public var addedByMemberId: UUID?

    public init(
        amount: Double,
        currency: String,
        fxRateToGoalCurrency: Double = 1,
        note: String? = nil,
        date: Date = Date(),
        addedByMemberId: UUID? = nil
    ) {
        self.amount = amount
        self.currency = currency
        self.fxRateToGoalCurrency = fxRateToGoalCurrency
        self.note = note
        self.date = date
        self.addedByMemberId = addedByMemberId
    }
}

public struct GoalStepDraft: Sendable, Equatable {
    public var title: String
    public var note: String?
    public var assigneeMemberId: UUID?
    public var dueAt: Date?

    public init(
        title: String,
        note: String? = nil,
        assigneeMemberId: UUID? = nil,
        dueAt: Date? = nil
    ) {
        self.title = title
        self.note = note
        self.assigneeMemberId = assigneeMemberId
        self.dueAt = dueAt
    }
}

public protocol GoalRepository: Sendable {
    func create(_ draft: GoalDraft) async throws -> GoalDTO
    func update(_ goal: GoalDTO) async throws -> GoalDTO
    func setStatus(goalId: UUID, status: GoalStatus) async throws -> GoalDTO
    func goal(id: UUID) async throws -> GoalDTO?
    func goals(spaceId: UUID, statuses: [GoalStatus]) async throws -> [GoalDTO]
    func delete(id: UUID) async throws
    func addExpense(goalId: UUID, draft: GoalExpenseDraft) async throws -> GoalExpenseDTO
    func expenses(goalId: UUID) async throws -> [GoalExpenseDTO]
    func deleteExpense(id: UUID) async throws
    func addStep(goalId: UUID, draft: GoalStepDraft) async throws -> GoalStepDTO
    func updateStep(_ step: GoalStepDTO) async throws -> GoalStepDTO
    func toggleStep(stepId: UUID, by memberId: UUID?, at date: Date) async throws -> GoalStepDTO
    func deleteStep(id: UUID) async throws
    func reorderSteps(goalId: UUID, orderedStepIds: [UUID]) async throws -> [GoalStepDTO]
    func steps(goalId: UUID) async throws -> [GoalStepDTO]
    func datedSteps(spaceId: UUID) async throws -> [GoalStepDTO]
}

extension GoalRepository {
    public func goals(spaceId: UUID) async throws -> [GoalDTO] {
        try await goals(spaceId: spaceId, statuses: [.active])
    }

    public func toggleStep(stepId: UUID, by memberId: UUID?) async throws -> GoalStepDTO {
        try await toggleStep(stepId: stepId, by: memberId, at: Date())
    }
}
