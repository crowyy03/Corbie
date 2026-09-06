import CoreData
import Foundation

public final class TaskFolder: NSManagedObject {
    public static let entityName = "TaskFolder"

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var subtitle: String?
    @NSManaged public var templateRaw: String?
    @NSManaged public var anyoneCanCheck: Bool
    @NSManaged public var isPinnedShopping: Bool
    @NSManaged public var sortIndex: Int32
    @NSManaged public var createdByMemberId: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?
    @NSManaged public var tasks: Set<TaskItem>

    public var template: FolderTemplate {
        get { FolderTemplate(rawValue: templateRaw ?? "") ?? .empty }
        set { templateRaw = newValue.rawValue }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
