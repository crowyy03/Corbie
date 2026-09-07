import CoreData
import Foundation

public final class Space: NSManagedObject {
    public static let entityName = "Space"

    @NSManaged public var id: UUID?
    @NSManaged public var createdAt: Date?
    @NSManaged public var creatorMemberId: UUID?
    @NSManaged public var togetherSince: Date?
    @NSManaged public var weddingDate: Date?
    @NSManaged public var displayCurrency: String?
    @NSManaged public var subscriptionStatusRaw: String?
    @NSManaged public var subscriptionExpiresAt: Date?
    @NSManaged public var subscriptionPayerMemberId: UUID?
    @NSManaged public var anchorTimeZone: String?
    @NSManaged public var questionSeed: Int64
    @NSManaged public var questionIndex: Int32

    @NSManaged public var members: Set<Member>
    @NSManaged public var tasks: Set<TaskItem>
    @NSManaged public var events: Set<Event>
    @NSManaged public var wishes: Set<Wish>
    @NSManaged public var plans: Set<Plan>
    @NSManaged public var lists: Set<ChecklistList>
    @NSManaged public var busyIntervals: Set<BusyInterval>
    @NSManaged public var capsules: Set<CapsuleItem>
    @NSManaged public var votes: Set<Vote>
    @NSManaged public var people: Set<Person>
    @NSManaged public var questions: Set<DailyQuestion>
    @NSManaged public var choreSets: Set<ChoreSet>

    public var subscriptionStatus: SubscriptionStatus {
        get { SubscriptionStatus(rawValue: subscriptionStatusRaw ?? "") ?? .none }
        set { subscriptionStatusRaw = newValue.rawValue }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
