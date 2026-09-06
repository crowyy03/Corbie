import CoreData
import Foundation

public final class TaskItem: NSManagedObject {
    public static let entityName = "TaskItem"

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var note: String?
    @NSManaged public var assigneeMemberId: UUID?
    @NSManaged public var dueAt: Date?
    @NSManaged public var isDone: Bool
    @NSManaged public var doneByMemberId: UUID?
    @NSManaged public var doneAt: Date?
    @NSManaged public var createdByMemberId: UUID?
    @NSManaged public var takenAt: Date?
    @NSManaged public var recurrenceRaw: String?
    @NSManaged public var placeName: String?
    @NSManaged public var address: String?
    @NSManaged public var lat: NSNumber?
    @NSManaged public var lon: NSNumber?
    @NSManaged public var sortIndex: Int32
    @NSManaged public var sourceGoalId: UUID?
    @NSManaged public var archivedAt: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?
    @NSManaged public var folder: TaskFolder?

    public var recurrence: Recurrence {
        get { Recurrence(rawValue: recurrenceRaw ?? "") ?? .none }
        set { recurrenceRaw = newValue.rawValue }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
