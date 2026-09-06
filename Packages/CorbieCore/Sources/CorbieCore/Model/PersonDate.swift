import CoreData
import Foundation

public final class PersonDate: NSManagedObject {
    public static let entityName = "PersonDate"

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var month: NSNumber?
    @NSManaged public var day: NSNumber?
    @NSManaged public var year: NSNumber?
    @NSManaged public var remindersEnabled: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var person: Person?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
