import Foundation

public enum CorbieEventPublishOutcome: Sendable, Equatable {
    case published(Int)
    case throttled
    case sharingDisabled
}

public actor CorbieEventBusyPublisher {
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
        sharesBusyTimes: Bool,
        force: Bool = false
    ) async throws -> CorbieEventPublishOutcome {
        guard sharesBusyTimes else { return .sharingDisabled }
        let moment = now()
        if force == false,
           let lastPublishedAt,
           moment.timeIntervalSince(lastPublishedAt) < BusyWindow.throttle {
            return .throttled
        }
        guard let horizon = calendar.date(byAdding: .day, value: BusyWindow.horizonDays, to: moment)
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
