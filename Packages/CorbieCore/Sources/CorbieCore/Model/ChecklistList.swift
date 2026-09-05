import CoreData
import Foundation

public final class ChecklistList: NSManagedObject {
    public static let entityName = "ChecklistList"

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var subtitle: String?
    @NSManaged public var templateRaw: String?
    @NSManaged public var anyoneCanCheck: Bool
    @NSManaged public var isPinnedShopping: Bool
    @NSManaged public var createdByMemberId: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?
    @NSManaged public var items: Set<ListItem>

    public var template: ListTemplate {
        get { ListTemplate(rawValue: templateRaw ?? "") ?? .empty }
        set { templateRaw = newValue.rawValue }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
