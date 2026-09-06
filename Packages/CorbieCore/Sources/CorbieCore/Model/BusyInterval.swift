import CoreData
import Foundation

public final class BusyInterval: NSManagedObject {
    public static let entityName = "BusyInterval"

    @NSManaged public var id: UUID?
    @NSManaged public var memberId: UUID?
    @NSManaged public var startAt: Date?
    @NSManaged public var endAt: Date?
    @NSManaged public var sourceRaw: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var space: Space?

    public var source: BusyIntervalSource {
        get { BusyIntervalSource(rawValue: sourceRaw ?? "") ?? .device }
        set { sourceRaw = newValue.rawValue }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        updatedAt = Date()
    }
}
