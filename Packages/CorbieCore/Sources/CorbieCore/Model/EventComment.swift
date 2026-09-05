import CoreData
import Foundation

public final class EventComment: NSManagedObject {
    public static let entityName = "EventComment"
    public static let maxLength = 200

    @NSManaged public var id: UUID?
    @NSManaged public var memberId: UUID?
    @NSManaged public var text: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var event: Event?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
