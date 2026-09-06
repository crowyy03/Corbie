import Foundation

public protocol BusyIntervalStore: Sendable {
    func replace(memberId: UUID, source: BusyIntervalSource, intervals: [BusyRange]) async throws
    func intervals(spaceId: UUID, from: Date, to: Date) async throws -> [BusyRange]
    func deleteAll(memberId: UUID) async throws
}

public enum BusyWindow {
    public static let horizonDays = 14
    public static let throttle: TimeInterval = 60 * 60
}

public enum BusyPublishOutcome: Sendable, Equatable {
    case published(Int)
    case throttled
    case sharingDisabled
    case accessDenied
}

public actor BusyPublisher {
    public static let changeDebounce = Duration.seconds(30)

    private let source: any DeviceCalendarSource
    private let store: any BusyIntervalStore
    private let calendar: Calendar
    private let debounce: Duration
    private let now: @Sendable () -> Date
    private var lastPublishedAt: Date?
    private var pendingChange: Task<Void, Never>?

    public init(
        source: any DeviceCalendarSource,
        store: any BusyIntervalStore,
        calendar: Calendar = .current,
        debounce: Duration = BusyPublisher.changeDebounce,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.source = source
        self.store = store
        self.calendar = calendar
        self.debounce = debounce
        self.now = now
    }

    @discardableResult
    public func publish(memberId: UUID, sharesBusyTimes: Bool, force: Bool = false) async throws -> BusyPublishOutcome {
        guard sharesBusyTimes else { return .sharingDisabled }
        let moment = now()
        if force == false, let lastPublishedAt, moment.timeIntervalSince(lastPublishedAt) < BusyWindow.throttle {
            return .throttled
        }
        guard try await source.requestAccess() else { return .accessDenied }
        guard let horizon = calendar.date(byAdding: .day, value: BusyWindow.horizonDays, to: moment) else {
            throw CorbieError.invalidInput("busy horizon")
        }
        let found = try await source.busyRanges(from: moment, to: horizon)
        let clipped = found.compactMap { interval -> DateInterval? in
            let start = max(interval.start, moment)
            let end = min(interval.end, horizon)
            guard end > start else { return nil }
            return DateInterval(start: start, end: end)
        }
        let intervals = BusyIntervals.merged(clipped).map {
            BusyRange(memberId: memberId, start: $0.start, end: $0.end)
        }
        try await store.replace(memberId: memberId, source: .device, intervals: intervals)
        lastPublishedAt = moment
        return .published(intervals.count)
    }

    public func disableSharing(memberId: UUID) async throws {
        pendingChange?.cancel()
        pendingChange = nil
        lastPublishedAt = nil
        try await store.deleteAll(memberId: memberId)
    }

    public func calendarStoreChanged(memberId: UUID, sharesBusyTimes: Bool) {
        pendingChange?.cancel()
        pendingChange = Task {
            try? await Task.sleep(for: debounce)
            guard Task.isCancelled == false else { return }
            _ = try? await publish(memberId: memberId, sharesBusyTimes: sharesBusyTimes, force: true)
        }
    }
}
