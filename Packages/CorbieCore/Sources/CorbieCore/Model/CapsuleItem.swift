import CoreData
import Foundation

public final class CapsuleItem: NSManagedObject {
    public static let entityName = "Capsule"
    public static let maxBodyLength = 5000

    @NSManaged public var id: UUID?
    @NSManaged public var authorMemberId: UUID?
    @NSManaged public var recipientMemberId: UUID?
    @NSManaged public var title: String?
    @NSManaged public var body: String?
    @NSManaged public var opensAt: Date?
    @NSManaged public var openedAt: Date?
    @NSManaged public var openedByMemberIdsData: Data?
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?

    public var openedByMemberIds: [UUID] {
        get { JSONValue.decode([UUID].self, from: openedByMemberIdsData) ?? [] }
        set { openedByMemberIdsData = JSONValue.encode(newValue) }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
