import CoreData
import Foundation

public final class PlanExpense: NSManagedObject {
    public static let entityName = "PlanExpense"

    @NSManaged public var id: UUID?
    @NSManaged public var amount: Double
    @NSManaged public var currency: String?
    @NSManaged public var fxRateToPlanCurrency: Double
    @NSManaged public var amountInPlanCurrency: Double
    @NSManaged public var note: String?
    @NSManaged public var date: Date?
    @NSManaged public var addedByMemberId: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var plan: Plan?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        date = Date()
    }
}
