import CoreData
import Foundation

public final class ListItem: NSManagedObject {
    public static let entityName = "ListItem"

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var isChecked: Bool
    @NSManaged public var checkedByMemberId: UUID?
    @NSManaged public var checkedAt: Date?
    @NSManaged public var addedByMemberId: UUID?
    @NSManaged public var note: String?
    @NSManaged public var placeName: String?
    @NSManaged public var address: String?
    @NSManaged public var latitude: NSNumber?
    @NSManaged public var longitude: NSNumber?
    @NSManaged public var sortIndex: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var list: ChecklistList?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
