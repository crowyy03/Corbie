import Foundation
import Testing
@testable import CorbieCore

private struct BusyStoreWrite: Sendable, Equatable {
    let memberId: UUID
    let source: BusyRangeSource
    let intervals: [BusyRange]
}

private struct BusyStoreDeletion: Sendable, Equatable {
    let memberId: UUID
    let source: BusyRangeSource
}

private actor FakeBusyStore: BusyIntervalStore {
    private(set) var writes: [BusyStoreWrite] = []
    private(set) var deletions: [BusyStoreDeletion] = []
    private var kept: [BusyRange] = []

    func replace(memberId: UUID, source: BusyRangeSource, intervals: [BusyRange]) async throws {
        writes.append(BusyStoreWrite(memberId: memberId, source: source, intervals: intervals))
        kept.removeAll { $0.memberId == memberId }
        kept.append(contentsOf: intervals)
    }

    func intervals(spaceId: UUID, from: Date, to: Date) async throws -> [BusyRange] {
        kept.filter { $0.end > from && $0.start < to }
    }

    func deleteAll(memberId: UUID, source: BusyRangeSource) async throws {
        deletions.append(BusyStoreDeletion(memberId: memberId, source: source))
        kept.removeAll { $0.memberId == memberId }
    }

    var lastIntervals: [BusyRange] { writes.last?.intervals ?? [] }
}

private actor FakeDeviceCalendar: DeviceCalendarSource {
    private let events: [DeviceCalendarEvent]
    private let calendar: Calendar
    private let grantsAccess: Bool
    private(set) var accessCalls = 0
    private(set) var queries: [DateInterval] = []

    init(events: [DeviceCalendarEvent], calendar: Calendar, grantsAccess: Bool = true) {
        self.events = events
        self.calendar = calendar
        self.grantsAccess = grantsAccess
    }

    func requestAccess() async throws -> Bool {
        accessCalls += 1
        return grantsAccess
    }

    func busyRanges(from: Date, to: Date) async throws -> [DateInterval] {
        queries.append(DateInterval(start: from, end: to))
        return DeviceCalendarBusy.intervals(from: events, calendar: calendar)
            .filter { $0.end > from && $0.start < to }
    }
}

private final class TestClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date

    init(_ value: Date) { self.value = value }

    var current: Date {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func advance(_ seconds: TimeInterval) {
        lock.lock()
        value = value.addingTimeInterval(seconds)
        lock.unlock()
    }
}

@Suite struct DomainBusyPublisherTests {
    private let utc = DomainClock.calendar()
    private let memberId = UUID()

    private func date(_ value: String) -> Date {
        DomainClock.date(value, in: utc)
    }

    private func publisher(
        _ source: FakeDeviceCalendar,
        _ store: FakeBusyStore,
        clock: TestClock
    ) -> BusyPublisher {
        BusyPublisher(
            source: source,
            store: store,
            calendar: utc,
            debounce: .zero,
            now: { clock.current }
        )
    }

    private func waitForWrites(_ store: FakeBusyStore, count: Int) async -> Int {
        for _ in 0 ..< 200 {
            let written = await store.writes.count
            if written >= count { return written }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return await store.writes.count
    }

    @Test func aSecondPublishInsideTheHourIsThrottled() async throws {
        let clock = TestClock(date("2026-09-10 09:00"))
        let source = FakeDeviceCalendar(
            events: [DeviceCalendarEvent(start: date("2026-09-11 10:00"), end: date("2026-09-11 11:00"))],
            calendar: utc
        )
        let store = FakeBusyStore()
        let publisher = publisher(source, store, clock: clock)

        #expect(try await publisher.publish(memberId: memberId, sharesBusyTimes: true) == .published(1))
        #expect(try await publisher.publish(memberId: memberId, sharesBusyTimes: true) == .throttled)
        #expect(await store.writes.count == 1)

        #expect(try await publisher.publish(memberId: memberId, sharesBusyTimes: true, force: true) == .published(1))
        #expect(await store.writes.count == 2)

        clock.advance(60 * 60 + 1)
        #expect(try await publisher.publish(memberId: memberId, sharesBusyTimes: true) == .published(1))
        #expect(await store.writes.count == 3)
    }

    @Test func publishingWithSharingOffNeverReachesTheCalendar() async throws {
        let clock = TestClock(date("2026-09-10 09:00"))
        let source = FakeDeviceCalendar(events: [], calendar: utc)
        let store = FakeBusyStore()
        let publisher = publisher(source, store, clock: clock)

        #expect(try await publisher.publish(memberId: memberId, sharesBusyTimes: false) == .sharingDisabled)
        #expect(await source.accessCalls == 0)
        #expect(await store.writes.isEmpty)
    }

    @Test func disablingSharingDeletesTheDeviceRanges() async throws {
        let clock = TestClock(date("2026-09-10 09:00"))
        let source = FakeDeviceCalendar(
            events: [DeviceCalendarEvent(start: date("2026-09-11 10:00"), end: date("2026-09-11 11:00"))],
            calendar: utc
        )
        let store = FakeBusyStore()
        let publisher = publisher(source, store, clock: clock)

        try await publisher.publish(memberId: memberId, sharesBusyTimes: true)
        #expect(try await store.intervals(spaceId: UUID(), from: .distantPast, to: .distantFuture).count == 1)

        try await publisher.disableSharing(memberId: memberId)
        #expect(await store.deletions == [BusyStoreDeletion(memberId: memberId, source: .device)])
        #expect(try await store.intervals(spaceId: UUID(), from: .distantPast, to: .distantFuture).isEmpty)
    }

    @Test func freeAndDeclinedEventsNeverBecomeBusyRanges() async throws {
        let clock = TestClock(date("2026-09-10 09:00"))
        let source = FakeDeviceCalendar(
            events: [
                DeviceCalendarEvent(start: date("2026-09-11 10:00"), end: date("2026-09-11 11:00")),
                DeviceCalendarEvent(start: date("2026-09-11 12:00"), end: date("2026-09-11 13:00"), isFree: true),
                DeviceCalendarEvent(start: date("2026-09-11 14:00"), end: date("2026-09-11 15:00"), isDeclined: true)
            ],
            calendar: utc
        )
        let store = FakeBusyStore()
        let publisher = publisher(source, store, clock: clock)

        #expect(try await publisher.publish(memberId: memberId, sharesBusyTimes: true) == .published(1))
        let written = await store.lastIntervals
        #expect(written == [BusyRange(memberId: memberId, start: date("2026-09-11 10:00"), end: date("2026-09-11 11:00"))])
    }

    @Test func anAllDayEventCoversTheWholeDay() async throws {
        let clock = TestClock(date("2026-09-10 09:00"))
        let source = FakeDeviceCalendar(
            events: [
                DeviceCalendarEvent(
                    start: date("2026-09-12"),
                    end: date("2026-09-12 23:59").addingTimeInterval(59),
                    isAllDay: true
                )
            ],
            calendar: utc
        )
        let store = FakeBusyStore()
        let publisher = publisher(source, store, clock: clock)

        #expect(try await publisher.publish(memberId: memberId, sharesBusyTimes: true) == .published(1))
        let written = await store.lastIntervals
        #expect(written.first?.start == date("2026-09-12"))
        #expect(written.first?.end == date("2026-09-13"))
    }

    @Test func overlappingEventsAreMergedIntoOneRange() async throws {
        let clock = TestClock(date("2026-09-10 09:00"))
        let source = FakeDeviceCalendar(
            events: [
                DeviceCalendarEvent(start: date("2026-09-11 10:00"), end: date("2026-09-11 12:00")),
                DeviceCalendarEvent(start: date("2026-09-11 11:00"), end: date("2026-09-11 13:00"))
            ],
            calendar: utc
        )
        let store = FakeBusyStore()
        let publisher = publisher(source, store, clock: clock)

        #expect(try await publisher.publish(memberId: memberId, sharesBusyTimes: true) == .published(1))
        let written = await store.lastIntervals
        #expect(written.first?.start == date("2026-09-11 10:00"))
        #expect(written.first?.end == date("2026-09-11 13:00"))
    }

    @Test func theHorizonIsTwoWeeksAndNothingStartsBeforeNow() async throws {
        let clock = TestClock(date("2026-09-10 09:00"))
        let source = FakeDeviceCalendar(
            events: [DeviceCalendarEvent(start: date("2026-09-10 08:00"), end: date("2026-09-10 12:00"))],
            calendar: utc
        )
        let store = FakeBusyStore()
        let publisher = publisher(source, store, clock: clock)

        try await publisher.publish(memberId: memberId, sharesBusyTimes: true)
        #expect(await source.queries == [DateInterval(start: date("2026-09-10 09:00"), end: date("2026-09-24 09:00"))])
        let written = await store.lastIntervals
        #expect(written.first?.start == date("2026-09-10 09:00"))
        #expect(written.first?.end == date("2026-09-10 12:00"))
    }

    @Test func aDeniedCalendarWritesNothing() async throws {
        let clock = TestClock(date("2026-09-10 09:00"))
        let source = FakeDeviceCalendar(events: [], calendar: utc, grantsAccess: false)
        let store = FakeBusyStore()
        let publisher = publisher(source, store, clock: clock)

        #expect(try await publisher.publish(memberId: memberId, sharesBusyTimes: true) == .accessDenied)
        #expect(await store.writes.isEmpty)
    }

    @Test func aCalendarChangePublishesAgainInsideTheThrottleWindow() async throws {
        let clock = TestClock(date("2026-09-10 09:00"))
        let source = FakeDeviceCalendar(
            events: [DeviceCalendarEvent(start: date("2026-09-11 10:00"), end: date("2026-09-11 11:00"))],
            calendar: utc
        )
        let store = FakeBusyStore()
        let publisher = publisher(source, store, clock: clock)

        try await publisher.publish(memberId: memberId, sharesBusyTimes: true)
        await publisher.calendarStoreChanged(memberId: memberId, sharesBusyTimes: true)
        #expect(await waitForWrites(store, count: 2) == 2)
    }

    @Test func aMultiDayAllDayEventCoversEveryDayItTouches() {
        let intervals = DeviceCalendarBusy.intervals(
            from: [
                DeviceCalendarEvent(
                    start: date("2026-09-12 00:00"),
                    end: date("2026-09-14 23:59"),
                    isAllDay: true
                )
            ],
            calendar: utc
        )
        #expect(intervals.count == 1)
        #expect(intervals.first?.start == date("2026-09-12"))
        #expect(intervals.first?.end == date("2026-09-15"))
    }

    @Test func anAllDayEventEndingAtMidnightIsNotStretchedByAnotherDay() {
        let intervals = DeviceCalendarBusy.intervals(
            from: [DeviceCalendarEvent(start: date("2026-09-12"), end: date("2026-09-13"), isAllDay: true)],
            calendar: utc
        )
        #expect(intervals.first?.end == date("2026-09-13"))
    }

    @Test func anEventWithNoLengthIsDropped() {
        let intervals = DeviceCalendarBusy.intervals(
            from: [DeviceCalendarEvent(start: date("2026-09-12 10:00"), end: date("2026-09-12 10:00"))],
            calendar: utc
        )
        #expect(intervals.isEmpty)
    }
}
