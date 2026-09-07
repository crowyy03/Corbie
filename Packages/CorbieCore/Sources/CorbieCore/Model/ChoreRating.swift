import CoreData
import Foundation

public final class ChoreRating: NSManagedObject {
    public static let entityName = "ChoreRating"

    @NSManaged public var id: UUID?
    @NSManaged public var memberId: UUID?
    @NSManaged public var verdictRaw: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var choreItem: ChoreItem?

    public var verdict: ChoreVerdict {
        get { ChoreVerdict(rawValue: verdictRaw ?? "") ?? .neutral }
        set { verdictRaw = newValue.rawValue }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
