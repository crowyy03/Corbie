import CoreData
import Foundation

public final class ChoreItem: NSManagedObject {
    public static let entityName = "ChoreItem"

    @NSManaged public var id: UUID?
    @NSManaged public var catalogId: String?
    @NSManaged public var title: String?
    @NSManaged public var frequencyRaw: String?
    @NSManaged public var isIncluded: Bool
    @NSManaged public var addedByMemberId: UUID?
    @NSManaged public var sortIndex: Int32
    @NSManaged public var choreSet: ChoreSet?
    @NSManaged public var ratings: Set<ChoreRating>
    @NSManaged public var assignments: Set<ChoreAssignment>

    public var frequency: ChoreFrequency {
        get { ChoreFrequency(rawValue: frequencyRaw ?? "") ?? .weekly }
        set { frequencyRaw = newValue.rawValue }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
    }
}
