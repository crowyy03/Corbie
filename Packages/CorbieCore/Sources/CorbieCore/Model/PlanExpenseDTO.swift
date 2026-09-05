import Foundation

public struct PlanExpenseDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var planId: UUID?
    public var amount: Double
    public var currency: String
    public var fxRateToPlanCurrency: Double
    public var amountInPlanCurrency: Double
    public var note: String?
    public var date: Date?
    public var addedByMemberId: UUID?

    public init(
        id: UUID,
        planId: UUID? = nil,
        amount: Double = 0,
        currency: String = "USD",
        fxRateToPlanCurrency: Double = 1,
        amountInPlanCurrency: Double = 0,
        note: String? = nil,
        date: Date? = nil,
        addedByMemberId: UUID? = nil
    ) {
        self.id = id
        self.planId = planId
        self.amount = amount
        self.currency = currency
        self.fxRateToPlanCurrency = fxRateToPlanCurrency
        self.amountInPlanCurrency = amountInPlanCurrency
        self.note = note
        self.date = date
        self.addedByMemberId = addedByMemberId
    }

    public init(_ expense: PlanExpense) {
        self.init(
            id: expense.id ?? UUID(),
            planId: expense.plan?.id,
            amount: expense.amount,
            currency: expense.currency ?? "USD",
            fxRateToPlanCurrency: expense.fxRateToPlanCurrency,
            amountInPlanCurrency: expense.amountInPlanCurrency,
            note: expense.note,
            date: expense.date,
            addedByMemberId: expense.addedByMemberId
        )
    }

    public var isConverted: Bool { fxRateToPlanCurrency != 1 }
}
