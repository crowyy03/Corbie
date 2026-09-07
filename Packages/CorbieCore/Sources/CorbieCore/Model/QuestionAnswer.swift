import CoreData
import Foundation

public final class QuestionAnswer: NSManagedObject {
    public static let entityName = "QuestionAnswer"

    @NSManaged public var id: UUID?
    @NSManaged public var memberId: UUID?
    @NSManaged public var text: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var editedAt: Date?
    @NSManaged public var dailyQuestion: DailyQuestion?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
