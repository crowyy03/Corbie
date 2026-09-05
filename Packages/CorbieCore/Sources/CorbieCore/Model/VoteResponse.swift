import CoreData
import Foundation

public final class VoteResponse: NSManagedObject {
    public static let entityName = "VoteResponse"

    @NSManaged public var id: UUID?
    @NSManaged public var memberId: UUID?
    @NSManaged public var optionIndexesData: Data?
    @NSManaged public var answeredAt: Date?
    @NSManaged public var vote: Vote?

    public var optionIndexes: [Int] {
        get { JSONValue.decode([Int].self, from: optionIndexesData) ?? [] }
        set { optionIndexesData = JSONValue.encode(newValue) }
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        answeredAt = Date()
    }
}

extension VoteResponses {
    public init(_ records: Set<VoteResponse>) {
        var byMember: [String: [Int]] = [:]
        for record in records {
            guard let memberId = record.memberId else { continue }
            byMember[memberId.uuidString] = record.optionIndexes
        }
        self.init(byMember: byMember)
    }
}
