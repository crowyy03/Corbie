import CoreData
import Foundation

public final class Member: NSManagedObject {
    public static let entityName = "Member"

    @NSManaged public var id: UUID?
    @NSManaged public var appleUserHash: String?
    @NSManaged public var displayName: String?
    @NSManaged public var colorKey: String?
    @NSManaged public var birthdayMonth: NSNumber?
    @NSManaged public var birthdayDay: NSNumber?
    @NSManaged public var joinedAt: Date?
    @NSManaged public var lastSeenAt: Date?
    @NSManaged public var sharesBusyTimes: Bool
    @NSManaged public var lastRecapSeenAt: Date?
    @NSManaged public var lastUsVisitAt: Date?
    @NSManaged public var lastQuestionSeenDayKey: String?
    @NSManaged public var notificationPrefsData: Data?
    @NSManaged public var space: Space?

    public var notificationPrefs: NotificationPrefs {
        get { JSONValue.decode(NotificationPrefs.self, from: notificationPrefsData) ?? .allEnabled }
        set { notificationPrefsData = JSONValue.encode(newValue) }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        joinedAt = Date()
    }
}
