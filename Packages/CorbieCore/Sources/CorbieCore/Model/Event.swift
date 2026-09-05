import CoreData
import Foundation

public final class Event: NSManagedObject {
    public static let entityName = "Event"

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var startAt: Date?
    @NSManaged public var endAt: Date?
    @NSManaged public var isAllDay: Bool
    @NSManaged public var kindRaw: String?
    @NSManaged public var personId: UUID?
    @NSManaged public var locationName: String?
    @NSManaged public var address: String?
    @NSManaged public var latitude: NSNumber?
    @NSManaged public var longitude: NSNumber?
    @NSManaged public var note: String?
    @NSManaged public var reminderOffsetsData: Data?
    @NSManaged public var createdByMemberId: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?
    @NSManaged public var comments: Set<EventComment>

    public var kind: EventKind {
        get { EventKind(rawValue: kindRaw ?? "") ?? .event }
        set { kindRaw = newValue.rawValue }
    }

    public var reminderOffsets: [ReminderOffset] {
        get { JSONValue.decode([ReminderOffset].self, from: reminderOffsetsData) ?? [] }
        set { reminderOffsetsData = JSONValue.encode(newValue) }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
