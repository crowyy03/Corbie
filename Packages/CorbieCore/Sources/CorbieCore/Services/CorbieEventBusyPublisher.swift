import Foundation

public enum CorbieEventPublishOutcome: Sendable, Equatable {
    case published(Int)
    case throttled
}

public actor CorbieEventBusyPublisher {
    public static let horizonDays = 14
    public static let throttle: TimeInterval = 60 * 60

    private let events: any EventRepository
    private let store: any BusyIntervalStore
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private var lastPublishedAt: Date?

    public init(
        events: any EventRepository,
        store: any BusyIntervalStore,
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.events = events
        self.store = store
        self.calendar = calendar
        self.now = now
    }

    @discardableResult
    public func publish(
        spaceId: UUID,
        memberId: UUID,
        force: Bool = false
    ) async throws -> CorbieEventPublishOutcome {
        let moment = now()
        if force == false,
           let lastPublishedAt,
           moment.timeIntervalSince(lastPublishedAt) < CorbieEventBusyPublisher.throttle {
            return .throttled
        }
        guard let horizon = calendar.date(byAdding: .day, value: CorbieEventBusyPublisher.horizonDays, to: moment)
        else {
            throw CorbieError.invalidInput("corbie busy horizon")
        }
        let found = try await events.events(spaceId: spaceId, from: moment, to: horizon)
        let ranges = CorbieEventBusy.intervals(from: found, calendar: calendar)
            .compactMap { interval -> BusyRange? in
                let start = max(interval.start, moment)
                let end = min(interval.end, horizon)
                guard end > start else { return nil }
                return BusyRange(memberId: memberId, start: start, end: end)
            }
        try await store.replace(memberId: memberId, source: .corbie, intervals: ranges)
        lastPublishedAt = moment
        return .published(ranges.count)
    }
}
