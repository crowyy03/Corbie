import Foundation

public struct RepositoryBusyIntervalStore: BusyIntervalStore {
    private let repository: any BusyIntervalRepository
    private let spaceId: UUID

    public init(repository: any BusyIntervalRepository, spaceId: UUID) {
        self.repository = repository
        self.spaceId = spaceId
    }

    public func replace(memberId: UUID, source: BusyIntervalSource, intervals: [BusyRange]) async throws {
        _ = try await repository.replace(
            spaceId: spaceId,
            memberId: memberId,
            source: source,
            intervals: intervals.map { BusyIntervalDraft(startAt: $0.start, endAt: $0.end) }
        )
    }

    public func intervals(spaceId: UUID, from: Date, to: Date) async throws -> [BusyRange] {
        try await repository.intervals(spaceId: spaceId, from: from, to: to).compactMap { interval in
            guard let memberId = interval.memberId else { return nil }
            return BusyRange(memberId: memberId, start: interval.startAt, end: interval.endAt)
        }
    }

    public func deleteAll(memberId: UUID, source: BusyIntervalSource) async throws {
        try await repository.deleteAll(memberId: memberId, source: source)
    }
}
