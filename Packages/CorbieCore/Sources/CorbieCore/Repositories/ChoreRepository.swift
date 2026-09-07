import Foundation

public struct ChoreItemDraft: Sendable, Equatable {
    public var catalogId: String?
    public var title: String
    public var frequency: ChoreFrequency
    public var addedByMemberId: UUID?

    public init(
        catalogId: String? = nil,
        title: String,
        frequency: ChoreFrequency = .weekly,
        addedByMemberId: UUID? = nil
    ) {
        self.catalogId = catalogId
        self.title = title
        self.frequency = frequency
        self.addedByMemberId = addedByMemberId
    }
}

public protocol ChoreRepository: Sendable {
    func activeSet(spaceId: UUID, viewerMemberId: UUID?) async throws -> ChoreSetDTO?
    func set(id: UUID, viewerMemberId: UUID?) async throws -> ChoreSetDTO?
    func startSet(spaceId: UUID, catalogIds: [String], memberId: UUID?, at date: Date) async throws -> ChoreSetDTO
    func addItem(setId: UUID, draft: ChoreItemDraft) async throws -> ChoreSetDTO
    func setIncluded(itemId: UUID, isIncluded: Bool) async throws -> ChoreSetDTO
    func setFrequency(itemId: UUID, frequency: ChoreFrequency) async throws -> ChoreSetDTO
    func removeItem(itemId: UUID) async throws -> ChoreSetDTO
    func startRating(setId: UUID) async throws -> ChoreSetDTO
    func rate(itemId: UUID, memberId: UUID, verdict: ChoreVerdict, at date: Date) async throws -> ChoreSetDTO
    func undoRating(itemId: UUID, memberId: UUID) async throws -> ChoreSetDTO
    func reveal(setId: UUID, at date: Date) async throws -> ChoreSetDTO
    func apply(setId: UUID, memberId: UUID?, at date: Date) async throws -> [TaskDTO]
    func history(spaceId: UUID, viewerMemberId: UUID?) async throws -> [ChoreSetDTO]
}

extension ChoreRepository {
    public func startSet(spaceId: UUID, catalogIds: [String], memberId: UUID?) async throws -> ChoreSetDTO {
        try await startSet(spaceId: spaceId, catalogIds: catalogIds, memberId: memberId, at: Date())
    }

    public func rate(itemId: UUID, memberId: UUID, verdict: ChoreVerdict) async throws -> ChoreSetDTO {
        try await rate(itemId: itemId, memberId: memberId, verdict: verdict, at: Date())
    }

    public func reveal(setId: UUID) async throws -> ChoreSetDTO {
        try await reveal(setId: setId, at: Date())
    }

    public func apply(setId: UUID, memberId: UUID?) async throws -> [TaskDTO] {
        try await apply(setId: setId, memberId: memberId, at: Date())
    }

    public func history(spaceId: UUID) async throws -> [ChoreSetDTO] {
        try await history(spaceId: spaceId, viewerMemberId: nil)
    }
}
