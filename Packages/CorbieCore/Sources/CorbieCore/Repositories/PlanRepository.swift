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

public struct ExpenseDraft: Sendable, Equatable {
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

public protocol PlanRepository: Sendable {
    func create(_ draft: PlanDraft) async throws -> PlanDTO
    func update(_ plan: PlanDTO) async throws -> PlanDTO
    func setStatus(planId: UUID, status: PlanStatus) async throws -> PlanDTO
    func plan(id: UUID) async throws -> PlanDTO?
    func plans(spaceId: UUID, statuses: [PlanStatus]) async throws -> [PlanDTO]
    func delete(id: UUID) async throws
    func addExpense(planId: UUID, draft: ExpenseDraft) async throws -> PlanExpenseDTO
    func expenses(planId: UUID) async throws -> [PlanExpenseDTO]
    func deleteExpense(id: UUID) async throws
}

extension PlanRepository {
    public func plans(spaceId: UUID) async throws -> [PlanDTO] {
        try await plans(spaceId: spaceId, statuses: [.active])
    }
}
