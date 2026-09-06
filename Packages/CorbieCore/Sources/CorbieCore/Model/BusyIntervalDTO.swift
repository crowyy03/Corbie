import Foundation

public struct BusyIntervalDTO: Sendable, Codable, Identifiable, Equatable {
    public let id: UUID
    public var spaceId: UUID?
    public var memberId: UUID?
    public var startAt: Date
    public var endAt: Date
    public var source: BusyIntervalSource
    public var updatedAt: Date?

    public init(
        id: UUID,
        spaceId: UUID? = nil,
        memberId: UUID? = nil,
        startAt: Date,
        endAt: Date,
        source: BusyIntervalSource = .device,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.spaceId = spaceId
        self.memberId = memberId
        self.startAt = startAt
        self.endAt = endAt
        self.source = source
        self.updatedAt = updatedAt
    }

    public init?(_ interval: BusyInterval) {
        guard let startAt = interval.startAt, let endAt = interval.endAt else { return nil }
        self.init(
            id: interval.id ?? UUID(),
            spaceId: interval.space?.id,
            memberId: interval.memberId,
            startAt: startAt,
            endAt: endAt,
            source: interval.source,
            updatedAt: interval.updatedAt
        )
    }

    public var duration: TimeInterval { max(0, endAt.timeIntervalSince(startAt)) }
}
