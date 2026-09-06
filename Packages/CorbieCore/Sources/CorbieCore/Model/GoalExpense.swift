import CoreData
import Foundation

public final class GoalExpense: NSManagedObject {
    public static let entityName = "GoalExpense"

    @NSManaged public var id: UUID?
    @NSManaged public var amount: Double
    @NSManaged public var currency: String?
    @NSManaged public var fxRateToGoalCurrency: Double
    @NSManaged public var amountInGoalCurrency: Double
    @NSManaged public var note: String?
    @NSManaged public var date: Date?
    @NSManaged public var addedByMemberId: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var goal: Goal?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        date = Date()
    }
}
