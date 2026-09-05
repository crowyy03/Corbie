import CoreData
import Foundation

public final class CapsuleItem: NSManagedObject {
    public static let entityName = "Capsule"
    public static let maxBodyLength = 5000

    @NSManaged public var id: UUID?
    @NSManaged public var authorMemberId: UUID?
    @NSManaged public var recipientMemberId: UUID?
    @NSManaged public var title: String?
    @NSManaged public var body: String?
    @NSManaged public var opensAt: Date?
    @NSManaged public var createdAt: Date?
    @NSManaged public var space: Space?
    @NSManaged public var opens: Set<CapsuleOpen>

    public var openedByMemberIds: [UUID] {
        var seen: Set<UUID> = []
        var result: [UUID] = []
        for record in sortedOpens {
            guard let memberId = record.memberId, seen.insert(memberId).inserted else { continue }
            result.append(memberId)
        }
        return result
    }

    public var openedAt: Date? {
        opens.compactMap(\.openedAt).min()
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }

    private var sortedOpens: [CapsuleOpen] {
        opens.sorted { lhs, rhs in
            let left = lhs.openedAt ?? .distantPast
            let right = rhs.openedAt ?? .distantPast
            guard left == right else { return left < right }
            return (lhs.memberId?.uuidString ?? "") < (rhs.memberId?.uuidString ?? "")
        }
    }
}
