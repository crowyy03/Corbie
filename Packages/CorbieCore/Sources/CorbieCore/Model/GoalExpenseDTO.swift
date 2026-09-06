import Foundation

public struct GoalExpenseDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var goalId: UUID?
    public var amount: Double
    public var currency: String
    public var fxRateToGoalCurrency: Double
    public var amountInGoalCurrency: Double
    public var note: String?
    public var date: Date?
    public var addedByMemberId: UUID?

    public init(
        id: UUID,
        goalId: UUID? = nil,
        amount: Double = 0,
        currency: String = "USD",
        fxRateToGoalCurrency: Double = 1,
        amountInGoalCurrency: Double = 0,
        note: String? = nil,
        date: Date? = nil,
        addedByMemberId: UUID? = nil
    ) {
        self.id = id
        self.goalId = goalId
        self.amount = amount
        self.currency = currency
        self.fxRateToGoalCurrency = fxRateToGoalCurrency
        self.amountInGoalCurrency = amountInGoalCurrency
        self.note = note
        self.date = date
        self.addedByMemberId = addedByMemberId
    }

    public init(_ expense: GoalExpense) {
        self.init(
            id: expense.id ?? UUID(),
            goalId: expense.goal?.id,
            amount: expense.amount,
            currency: expense.currency ?? "USD",
            fxRateToGoalCurrency: expense.fxRateToGoalCurrency,
            amountInGoalCurrency: expense.amountInGoalCurrency,
            note: expense.note,
            date: expense.date,
            addedByMemberId: expense.addedByMemberId
        )
    }

    public var isConverted: Bool { fxRateToGoalCurrency != 1 }
}
