import CoreData
import Foundation

public final class PlanStep: NSManagedObject {
    public static let entityName = "PlanStep"

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var note: String?
    @NSManaged public var isDone: Bool
    @NSManaged public var doneByMemberId: UUID?
    @NSManaged public var doneAt: Date?
    @NSManaged public var assigneeMemberId: UUID?
    @NSManaged public var dueAt: Date?
    @NSManaged public var sortIndex: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var plan: Plan?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
