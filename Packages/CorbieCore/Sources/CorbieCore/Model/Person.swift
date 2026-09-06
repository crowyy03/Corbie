import CoreData
import Foundation

public final class Person: NSManagedObject {
    public static let entityName = "Person"

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var relation: String?
    @NSManaged public var birthdayMonth: NSNumber?
    @NSManaged public var birthdayDay: NSNumber?
    @NSManaged public var birthdayYear: NSNumber?
    @NSManaged public var ownerMemberId: UUID?
    @NSManaged public var note: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?
    @NSManaged public var giftIdeas: Set<GiftIdea>
    @NSManaged public var dates: Set<PersonDate>

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
