import Foundation

public struct PlanDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var spaceId: UUID?
    public var title: String
    public var type: PlanType
    public var targetAmount: Double
    public var currency: String
    public var savedAmount: Double
    public var addedAmount: Double
    public var isOpenEnded: Bool
    public var startAt: Date?
    public var endAt: Date?
    public var status: PlanStatus
    public var createdByMemberId: UUID?
    public var note: String?
    public var createdAt: Date?
    public var expenseCount: Int
    public var stepCount: Int
    public var doneStepCount: Int

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        title: String = "",
        type: PlanType = .other,
        targetAmount: Double = 0,
        currency: String = "USD",
        savedAmount: Double = 0,
        addedAmount: Double = 0,
        isOpenEnded: Bool = false,
        startAt: Date? = nil,
        endAt: Date? = nil,
        status: PlanStatus = .active,
        createdByMemberId: UUID? = nil,
        note: String? = nil,
        createdAt: Date? = nil,
        expenseCount: Int = 0,
        stepCount: Int = 0,
        doneStepCount: Int = 0
    ) {
        self.id = id
        self.spaceId = spaceId
        self.title = title
        self.type = type
        self.targetAmount = targetAmount
        self.currency = currency
        self.savedAmount = savedAmount
        self.addedAmount = addedAmount
        self.isOpenEnded = isOpenEnded
        self.startAt = startAt
        self.endAt = endAt
        self.status = status
        self.createdByMemberId = createdByMemberId
        self.note = note
        self.createdAt = createdAt
        self.expenseCount = expenseCount
        self.stepCount = stepCount
        self.doneStepCount = doneStepCount
    }

    public init(_ plan: Plan) {
        let expenses = plan.expenses
        let steps = plan.steps
        self.init(
            id: plan.id ?? UUID(),
            spaceId: plan.space?.id,
            title: plan.title ?? "",
            type: plan.type,
            targetAmount: plan.targetAmount,
            currency: plan.currency ?? "USD",
            savedAmount: plan.savedAmount,
            addedAmount: expenses.reduce(0) { $0 + $1.amountInPlanCurrency },
            isOpenEnded: plan.isOpenEnded,
            startAt: plan.startAt,
            endAt: plan.endAt,
            status: plan.status,
            createdByMemberId: plan.createdByMemberId,
            note: plan.note,
            createdAt: plan.createdAt,
            expenseCount: expenses.count,
            stepCount: steps.count,
            doneStepCount: steps.filter(\.isDone).count
        )
    }

    public var totalSavedAmount: Double { savedAmount + addedAmount }

    public var total: Double { totalSavedAmount }

    public var contributionCount: Int { expenseCount }

    public var leftAmount: Double {
        guard isOpenEnded == false else { return 0 }
        return max(0, targetAmount - totalSavedAmount)
    }

    public var isOverspent: Bool { isOpenEnded == false && totalSavedAmount > targetAmount }

    public var overspentAmount: Double {
        guard isOpenEnded == false else { return 0 }
        return max(0, totalSavedAmount - targetAmount)
    }

    public var overspentFraction: Double {
        guard targetAmount > 0 else { return 0 }
        return overspentAmount / targetAmount
    }

    public var progress: Double {
        guard isOpenEnded == false, targetAmount > 0 else { return 0 }
        return min(1, max(0, totalSavedAmount / targetAmount))
    }

    public var showsProgress: Bool { isOpenEnded == false && targetAmount > 0 }
}
