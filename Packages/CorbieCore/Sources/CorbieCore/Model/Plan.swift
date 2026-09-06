import CoreData
import Foundation

public final class Plan: NSManagedObject {
    public static let entityName = "Plan"

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var typeRaw: String?
    @NSManaged public var targetAmount: Double
    @NSManaged public var currency: String?
    @NSManaged public var savedAmount: Double
    @NSManaged public var startAt: Date?
    @NSManaged public var endAt: Date?
    @NSManaged public var statusRaw: String?
    @NSManaged public var createdByMemberId: UUID?
    @NSManaged public var note: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?
    @NSManaged public var expenses: Set<PlanExpense>
    @NSManaged public var steps: Set<PlanStep>

    public var type: PlanType {
        get { PlanType(rawValue: typeRaw ?? "") ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    public var status: PlanStatus {
        get { PlanStatus(rawValue: statusRaw ?? "") ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
