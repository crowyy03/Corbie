import CoreData
import Foundation

public final class Wish: NSManagedObject {
    public static let entityName = "Wish"

    @NSManaged public var id: UUID?
    @NSManaged public var ownerMemberId: UUID?
    @NSManaged public var addedByMemberId: UUID?
    @NSManaged public var title: String?
    @NSManaged public var url: String?
    @NSManaged public var imageURL: String?
    @NSManaged public var localImage: Data?
    @NSManaged public var price: NSNumber?
    @NSManaged public var currency: String?
    @NSManaged public var priorityRaw: String?
    @NSManaged public var note: String?
    @NSManaged public var sourceRaw: String?
    @NSManaged public var isFulfilled: Bool
    @NSManaged public var fulfilledAt: Date?
    @NSManaged public var needsParse: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?

    public var priority: WishPriority {
        get { WishPriority(rawValue: priorityRaw ?? "") ?? .want }
        set { priorityRaw = newValue.rawValue }
    }

    public var source: WishSource {
        get { WishSource(rawValue: sourceRaw ?? "") ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
