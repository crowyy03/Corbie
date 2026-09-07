import CoreData
import Foundation

public final class ChoreSet: NSManagedObject {
    public static let entityName = "ChoreSet"

    @NSManaged public var id: UUID?
    @NSManaged public var statusRaw: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var revealedAt: Date?
    @NSManaged public var appliedAt: Date?
    @NSManaged public var space: Space?
    @NSManaged public var items: Set<ChoreItem>

    public var status: ChoreSetStatus {
        get { ChoreSetStatus(rawValue: statusRaw ?? "") ?? .building }
        set { statusRaw = newValue.rawValue }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
