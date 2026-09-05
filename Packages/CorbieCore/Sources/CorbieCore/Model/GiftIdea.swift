import CoreData
import Foundation

public final class GiftIdea: NSManagedObject {
    public static let entityName = "GiftIdea"

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var url: String?
    @NSManaged public var price: NSNumber?
    @NSManaged public var currency: String?
    @NSManaged public var note: String?
    @NSManaged public var isDone: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var person: Person?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
