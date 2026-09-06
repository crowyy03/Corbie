import Foundation

public struct BusyIntervalDraft: Sendable, Equatable {
    public var startAt: Date
    public var endAt: Date

    public init(startAt: Date, endAt: Date) {
        self.startAt = startAt
        self.endAt = endAt
    }
}

public protocol BusyIntervalRepository: Sendable {
    func replace(
        spaceId: UUID,
        memberId: UUID,
        source: BusyIntervalSource,
        intervals: [BusyIntervalDraft],
        at date: Date
    ) async throws -> [BusyIntervalDTO]
    func intervals(spaceId: UUID, from: Date, to: Date) async throws -> [BusyIntervalDTO]
    func deleteAll(memberId: UUID, source: BusyIntervalSource) async throws
    func purge(before date: Date) async throws
}

extension BusyIntervalRepository {
    public func replace(
        spaceId: UUID,
        memberId: UUID,
        source: BusyIntervalSource,
        intervals: [BusyIntervalDraft]
    ) async throws -> [BusyIntervalDTO] {
        try await replace(
            spaceId: spaceId,
            memberId: memberId,
            source: source,
            intervals: intervals,
            at: Date()
        )
    }
}
