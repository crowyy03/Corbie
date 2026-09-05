import CoreData
import Foundation

public final class Vote: NSManagedObject {
    public static let entityName = "Vote"

    @NSManaged public var id: UUID?
    @NSManaged public var question: String?
    @NSManaged public var optionsData: Data?
    @NSManaged public var modeRaw: String?
    @NSManaged public var createdByMemberId: UUID?
    @NSManaged public var responsesData: Data?
    @NSManaged public var revealWhenBothAnswered: Bool
    @NSManaged public var revealedAt: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?

    public var mode: VoteMode {
        get { VoteMode(rawValue: modeRaw ?? "") ?? .single }
        set { modeRaw = newValue.rawValue }
    }

    public var options: [String] {
        get { JSONValue.decode([String].self, from: optionsData) ?? [] }
        set { optionsData = JSONValue.encode(newValue) }
    }

    public var responses: VoteResponses {
        get { JSONValue.decode(VoteResponses.self, from: responsesData) ?? VoteResponses() }
        set { responsesData = JSONValue.encode(newValue) }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}
