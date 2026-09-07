import CoreData
import Foundation

public final class DailyQuestion: NSManagedObject {
    public static let entityName = "DailyQuestion"

    @NSManaged public var id: UUID?
    @NSManaged public var questionId: String?
    @NSManaged public var dayKey: String?
    @NSManaged public var nudgedByMemberId: UUID?
    @NSManaged public var nudgedAt: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?
    @NSManaged public var answers: Set<QuestionAnswer>

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
