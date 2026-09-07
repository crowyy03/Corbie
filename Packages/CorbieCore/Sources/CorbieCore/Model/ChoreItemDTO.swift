import Foundation

public struct ChoreItemDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var choreSetId: UUID?
    public var catalogId: String?
    public var title: String
    public var frequency: ChoreFrequency
    public var isIncluded: Bool
    public var addedByMemberId: UUID?
    public var sortIndex: Int
    public var ratings: [ChoreRatingDTO]
    public var assignment: ChoreAssignmentDTO?

    public init(
        id: UUID,
        choreSetId: UUID? = nil,
        catalogId: String? = nil,
        title: String = "",
        frequency: ChoreFrequency = .weekly,
        isIncluded: Bool = true,
        addedByMemberId: UUID? = nil,
        sortIndex: Int = 0,
        ratings: [ChoreRatingDTO] = [],
        assignment: ChoreAssignmentDTO? = nil
    ) {
        self.id = id
        self.choreSetId = choreSetId
        self.catalogId = catalogId
        self.title = title
        self.frequency = frequency
        self.isIncluded = isIncluded
        self.addedByMemberId = addedByMemberId
        self.sortIndex = sortIndex
        self.ratings = ratings
        self.assignment = assignment
    }

    public init(_ item: ChoreItem, title: String, showsEveryRating: Bool, viewerMemberId: UUID?) {
        let ratings = item.ratings
            .filter { showsEveryRating || ($0.memberId != nil && $0.memberId == viewerMemberId) }
            .map(ChoreRatingDTO.init)
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        let assignment = item.assignments
            .sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
            .last
        self.init(
            id: item.id ?? UUID(),
            choreSetId: item.choreSet?.id,
            catalogId: item.catalogId,
            title: title,
            frequency: item.frequency,
            isIncluded: item.isIncluded,
            addedByMemberId: item.addedByMemberId,
            sortIndex: Int(item.sortIndex),
            ratings: ratings,
            assignment: assignment.map(ChoreAssignmentDTO.init)
        )
    }

    public var loadPerWeek: Double { frequency.loadPerWeek }

    public var isCustom: Bool { catalogId == nil }

    public func verdict(of memberId: UUID?) -> ChoreVerdict? {
        guard let memberId else { return nil }
        return ratings.first { $0.memberId == memberId }?.verdict
    }
}
