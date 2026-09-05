import Foundation

public struct PlanDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var spaceId: UUID?
    public var title: String
    public var type: PlanType
    public var targetAmount: Double
    public var currency: String
    public var savedAmount: Double
    public var spentAmount: Double
    public var startAt: Date?
    public var endAt: Date?
    public var status: PlanStatus
    public var createdByMemberId: UUID?
    public var note: String?
    public var createdAt: Date?
    public var expenseCount: Int

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        title: String = "",
        type: PlanType = .other,
        targetAmount: Double = 0,
        currency: String = "USD",
        savedAmount: Double = 0,
        spentAmount: Double = 0,
        startAt: Date? = nil,
        endAt: Date? = nil,
        status: PlanStatus = .active,
        createdByMemberId: UUID? = nil,
        note: String? = nil,
        createdAt: Date? = nil,
        expenseCount: Int = 0
    ) {
        self.id = id
        self.spaceId = spaceId
        self.title = title
        self.type = type
        self.targetAmount = targetAmount
        self.currency = currency
        self.savedAmount = savedAmount
        self.spentAmount = spentAmount
        self.startAt = startAt
        self.endAt = endAt
        self.status = status
        self.createdByMemberId = createdByMemberId
        self.note = note
        self.createdAt = createdAt
        self.expenseCount = expenseCount
    }

    public init(_ plan: Plan) {
        let expenses = plan.expenses
        self.init(
            id: plan.id ?? UUID(),
            spaceId: plan.space?.id,
            title: plan.title ?? "",
            type: plan.type,
            targetAmount: plan.targetAmount,
            currency: plan.currency ?? "USD",
            savedAmount: plan.savedAmount,
            spentAmount: expenses.reduce(0) { $0 + $1.amountInPlanCurrency },
            startAt: plan.startAt,
            endAt: plan.endAt,
            status: plan.status,
            createdByMemberId: plan.createdByMemberId,
            note: plan.note,
            createdAt: plan.createdAt,
            expenseCount: expenses.count
        )
    }

    public var leftAmount: Double { targetAmount - spentAmount }

    public var isOverspent: Bool { spentAmount > targetAmount }

    public var overspentAmount: Double { max(0, spentAmount - targetAmount) }

    public var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1, max(0, savedAmount / targetAmount))
    }
}
