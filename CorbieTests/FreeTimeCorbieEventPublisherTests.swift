import CorbieCore
import XCTest
@testable import Corbie

private struct StubEventRepository: EventRepository {
    let stored: [EventDTO]

    func events(spaceId: UUID, from: Date?, to: Date?) async throws -> [EventDTO] { stored }

    func create(_ draft: EventDraft) async throws -> EventDTO { throw CorbieError.notFound("create") }
    func update(_ event: EventDTO) async throws -> EventDTO { throw CorbieError.notFound("update") }
    func event(id: UUID) async throws -> EventDTO? { nil }
    func delete(id: UUID) async throws {}
    func addComment(eventId: UUID, memberId: UUID?, text: String) async throws -> EventCommentDTO {
        throw CorbieError.notFound("addComment")
    }
    func comments(eventId: UUID) async throws -> [EventCommentDTO] { [] }
    func deleteComment(id: UUID) async throws {}
}

private actor RecordingBusyStore: BusyIntervalStore {
    private(set) var sources: [BusyIntervalSource] = []
    private(set) var written: [[BusyRange]] = []

    func replace(memberId: UUID, source: BusyIntervalSource, intervals: [BusyRange]) async throws {
        sources.append(source)
        written.append(intervals)
    }

    func intervals(spaceId: UUID, from: Date, to: Date) async throws -> [BusyRange] { [] }

    func deleteAll(memberId: UUID) async throws {}
}

final class FreeTimeCorbieEventPublisherTests: XCTestCase {
    private let calendar = CalendarTestSupport.calendar("en_US")
    private let spaceId = UUID()
    private let memberId = UUID()

    private var noon: Date { CalendarTestSupport.date(calendar, 2026, 9, 10, 12, 0) }

    private func publisher(
        events: [EventDTO],
        store: RecordingBusyStore,
        now: @escaping @Sendable () -> Date
    ) -> CorbieEventBusyPublisher {
        CorbieEventBusyPublisher(
            events: StubEventRepository(stored: events),
            store: store,
            calendar: calendar,
            now: now
        )
    }

    func testAnEventAlreadyRunningIsClippedToTheMomentOfPublishing() async throws {
        let event = CalendarTestSupport.event(
            calendar,
            title: "Workshop",
            start: CalendarTestSupport.date(calendar, 2026, 9, 10, 10, 0),
            end: CalendarTestSupport.date(calendar, 2026, 9, 10, 14, 0)
        )
        let store = RecordingBusyStore()
        let moment = noon

        let outcome = try await publisher(events: [event], store: store, now: { moment })
            .publish(spaceId: spaceId, memberId: memberId, sharesBusyTimes: true)

        XCTAssertEqual(outcome, .published(1))
        let written = await store.written
        let sources = await store.sources
        XCTAssertEqual(sources, [.corbie])
        XCTAssertEqual(
            written.first,
            [BusyRange(memberId: memberId, start: moment, end: CalendarTestSupport.date(calendar, 2026, 9, 10, 14, 0))]
        )
    }

    func testAnEventBeyondTheHorizonNeverReachesTheSpace() async throws {
        let event = CalendarTestSupport.event(
            calendar,
            title: "Far away",
            start: CalendarTestSupport.date(calendar, 2026, 10, 20, 10, 0),
            end: CalendarTestSupport.date(calendar, 2026, 10, 20, 11, 0)
        )
        let store = RecordingBusyStore()
        let moment = noon

        let outcome = try await publisher(events: [event], store: store, now: { moment })
            .publish(spaceId: spaceId, memberId: memberId, sharesBusyTimes: true)

        XCTAssertEqual(outcome, .published(0))
        let written = await store.written
        XCTAssertEqual(written, [[]])
    }

    func testASecondPublishInTheSameHourIsThrottledUnlessItIsForced() async throws {
        let event = CalendarTestSupport.event(
            calendar,
            title: "Workshop",
            start: CalendarTestSupport.date(calendar, 2026, 9, 10, 13, 0),
            end: CalendarTestSupport.date(calendar, 2026, 9, 10, 14, 0)
        )
        let store = RecordingBusyStore()
        let moment = noon
        let publisher = publisher(events: [event], store: store, now: { moment })

        _ = try await publisher.publish(spaceId: spaceId, memberId: memberId, sharesBusyTimes: true)
        let second = try await publisher.publish(spaceId: spaceId, memberId: memberId, sharesBusyTimes: true)
        let forced = try await publisher.publish(
            spaceId: spaceId,
            memberId: memberId,
            sharesBusyTimes: true,
            force: true
        )

        XCTAssertEqual(second, .throttled)
        XCTAssertEqual(forced, .published(1))
        let written = await store.written
        XCTAssertEqual(written.count, 2)
    }

    func testAMemberWhoDoesNotShareWritesNoCorbieEvents() async throws {
        let event = CalendarTestSupport.event(
            calendar,
            title: "Workshop",
            start: CalendarTestSupport.date(calendar, 2026, 9, 10, 13, 0),
            end: CalendarTestSupport.date(calendar, 2026, 9, 10, 14, 0)
        )
        let store = RecordingBusyStore()
        let moment = noon

        let outcome = try await publisher(events: [event], store: store, now: { moment })
            .publish(spaceId: spaceId, memberId: memberId, sharesBusyTimes: false)

        XCTAssertEqual(outcome, .sharingDisabled)
        let written = await store.written
        XCTAssertTrue(written.isEmpty)
    }
}
