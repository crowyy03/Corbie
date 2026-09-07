import Foundation

public struct ChoreSetDTO: Sendable, Codable, Identifiable, Equatable {
    public static let minimumIncludedItems = 8
    public static let resplitAfter: TimeInterval = 182 * 24 * 60 * 60

    public let id: UUID
    public var spaceId: UUID?
    public var status: ChoreSetStatus
    public var createdAt: Date?
    public var revealedAt: Date?
    public var appliedAt: Date?
    public var items: [ChoreItemDTO]
    public var ratedMemberIds: [UUID]

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        status: ChoreSetStatus = .building,
        createdAt: Date? = nil,
        revealedAt: Date? = nil,
        appliedAt: Date? = nil,
        items: [ChoreItemDTO] = [],
        ratedMemberIds: [UUID] = []
    ) {
        self.id = id
        self.spaceId = spaceId
        self.status = status
        self.createdAt = createdAt
        self.revealedAt = revealedAt
        self.appliedAt = appliedAt
        self.items = items
        self.ratedMemberIds = ratedMemberIds
    }

    public init(_ set: ChoreSet, showsEveryRating: Bool, viewerMemberId: UUID?, title: (ChoreItem) -> String) {
        let ordered = set.items.sorted { $0.sortIndex < $1.sortIndex }
        self.init(
            id: set.id ?? UUID(),
            spaceId: set.space?.id,
            status: set.status,
            createdAt: set.createdAt,
            revealedAt: set.revealedAt,
            appliedAt: set.appliedAt,
            items: ordered.map {
                ChoreItemDTO(
                    $0,
                    title: title($0),
                    showsEveryRating: showsEveryRating,
                    viewerMemberId: viewerMemberId
                )
            },
            ratedMemberIds: ChoreSetDTO.membersWhoRatedEverything(set).sorted { $0.uuidString < $1.uuidString }
        )
    }

    public var includedItems: [ChoreItemDTO] { items.filter(\.isIncluded) }

    public var canStartRating: Bool { includedItems.count >= ChoreSetDTO.minimumIncludedItems }

    public func hasRatedEverything(_ memberId: UUID?) -> Bool {
        guard let memberId else { return false }
        return ratedMemberIds.contains(memberId)
    }

    public func ratedItemCount(by memberId: UUID?) -> Int {
        guard let memberId else { return 0 }
        return includedItems.filter { $0.verdict(of: memberId) != nil }.count
    }

    public func needsResplit(at date: Date) -> Bool {
        guard let appliedAt else { return false }
        return date.timeIntervalSince(appliedAt) >= ChoreSetDTO.resplitAfter
    }

    private static func membersWhoRatedEverything(_ set: ChoreSet) -> Set<UUID> {
        let included = set.items.filter(\.isIncluded)
        guard included.isEmpty == false else { return [] }
        var counts: [UUID: Int] = [:]
        for item in included {
            for memberId in Set(item.ratings.compactMap(\.memberId)) {
                counts[memberId, default: 0] += 1
            }
        }
        return Set(counts.filter { $0.value == included.count }.keys)
    }
}
