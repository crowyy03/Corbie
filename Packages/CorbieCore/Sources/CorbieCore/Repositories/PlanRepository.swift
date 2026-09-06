import Foundation

public struct PlanDraft: Sendable, Equatable {
    public var spaceId: UUID
    public var title: String
    public var type: PlanType
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
        type: PlanType = .other,
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

public struct PlanExpenseDraft: Sendable, Equatable {
    public var amount: Double
    public var currency: String
    public var fxRateToPlanCurrency: Double
    public var note: String?
    public var date: Date
    public var addedByMemberId: UUID?

    public init(
        amount: Double,
        currency: String,
        fxRateToPlanCurrency: Double = 1,
        note: String? = nil,
        date: Date = Date(),
        addedByMemberId: UUID? = nil
    ) {
        self.amount = amount
        self.currency = currency
        self.fxRateToPlanCurrency = fxRateToPlanCurrency
        self.note = note
        self.date = date
        self.addedByMemberId = addedByMemberId
    }
}

public struct PlanStepDraft: Sendable, Equatable {
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

public protocol PlanRepository: Sendable {
    func create(_ draft: PlanDraft) async throws -> PlanDTO
    func update(_ plan: PlanDTO) async throws -> PlanDTO
    func setStatus(planId: UUID, status: PlanStatus) async throws -> PlanDTO
    func plan(id: UUID) async throws -> PlanDTO?
    func plans(spaceId: UUID, statuses: [PlanStatus]) async throws -> [PlanDTO]
    func delete(id: UUID) async throws
    func addExpense(planId: UUID, draft: PlanExpenseDraft) async throws -> PlanExpenseDTO
    func expenses(planId: UUID) async throws -> [PlanExpenseDTO]
    func deleteExpense(id: UUID) async throws
    func addStep(planId: UUID, draft: PlanStepDraft) async throws -> PlanStepDTO
    func updateStep(_ step: PlanStepDTO) async throws -> PlanStepDTO
    func toggleStep(stepId: UUID, by memberId: UUID?, at date: Date) async throws -> PlanStepDTO
    func deleteStep(id: UUID) async throws
    func reorderSteps(planId: UUID, orderedStepIds: [UUID]) async throws -> [PlanStepDTO]
    func steps(planId: UUID) async throws -> [PlanStepDTO]
    func datedSteps(spaceId: UUID) async throws -> [PlanStepDTO]
}

extension PlanRepository {
    public func plans(spaceId: UUID) async throws -> [PlanDTO] {
        try await plans(spaceId: spaceId, statuses: [.active])
    }

    public func toggleStep(stepId: UUID, by memberId: UUID?) async throws -> PlanStepDTO {
        try await toggleStep(stepId: stepId, by: memberId, at: Date())
    }
}
