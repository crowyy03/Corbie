import CoreData
import Foundation

public final class CapsuleOpen: NSManagedObject {
    public static let entityName = "CapsuleOpen"

    @NSManaged public var id: UUID?
    @NSManaged public var memberId: UUID?
    @NSManaged public var openedAt: Date?
    @NSManaged public var capsule: CapsuleItem?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        openedAt = Date()
    }
}
