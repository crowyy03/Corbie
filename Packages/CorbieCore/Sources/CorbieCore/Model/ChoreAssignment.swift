import CoreData
import Foundation

public final class ChoreAssignment: NSManagedObject {
    public static let entityName = "ChoreAssignment"

    @NSManaged public var id: UUID?
    @NSManaged public var resultRaw: String?
    @NSManaged public var assignedMemberId: UUID?
    @NSManaged public var memberAId: UUID?
    @NSManaged public var memberBId: UUID?
    @NSManaged public var scoreA: Int16
    @NSManaged public var scoreB: Int16
    @NSManaged public var createdAt: Date?
    @NSManaged public var choreItem: ChoreItem?

    public var result: ChoreAssignmentResult {
        get { ChoreAssignmentResult(rawValue: resultRaw ?? "") ?? .anyone }
        set { resultRaw = newValue.rawValue }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
