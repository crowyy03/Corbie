import Foundation

public struct GoalDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var spaceId: UUID?
    public var title: String
    public var type: GoalType
    public var targetAmount: Double
    public var currency: String
    public var savedAmount: Double
    public var addedAmount: Double
    public var startAt: Date?
    public var endAt: Date?
    public var status: GoalStatus
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
        type: GoalType = .other,
        targetAmount: Double = 0,
        currency: String = "USD",
        savedAmount: Double = 0,
        addedAmount: Double = 0,
        startAt: Date? = nil,
        endAt: Date? = nil,
        status: GoalStatus = .active,
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

    public init(_ goal: Goal) {
        let expenses = goal.expenses
        let steps = goal.steps
        self.init(
            id: goal.id ?? UUID(),
            spaceId: goal.space?.id,
            title: goal.title ?? "",
            type: goal.type,
            targetAmount: goal.targetAmount,
            currency: goal.currency ?? "USD",
            savedAmount: goal.savedAmount,
            addedAmount: expenses.reduce(0) { $0 + $1.amountInGoalCurrency },
            startAt: goal.startAt,
            endAt: goal.endAt,
            status: goal.status,
            createdByMemberId: goal.createdByMemberId,
            note: goal.note,
            createdAt: goal.createdAt,
            expenseCount: expenses.count,
            stepCount: steps.count,
            doneStepCount: steps.filter(\.isDone).count
        )
    }

    public var totalSavedAmount: Double { savedAmount + addedAmount }

    public var leftAmount: Double { max(0, targetAmount - totalSavedAmount) }

    public var isOverspent: Bool { totalSavedAmount > targetAmount }

    public var overspentAmount: Double { max(0, totalSavedAmount - targetAmount) }

    public var progress: Double {
        guard targetAmount > 0 else { return 0 }
        return min(1, max(0, totalSavedAmount / targetAmount))
    }
}
