import Foundation
import Testing
@testable import CorbieCore

@Suite struct EventRepositoryTests {
    private let day = TimeInterval(86_400)
    private let start = Date(timeIntervalSince1970: 1_757_000_000)

    @Test func rangeReturnsEventsThatOverlapIt() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.events
        let spaceId = world.space.id
        let inside = try await repository.create(
            EventDraft(spaceId: spaceId, title: "Dinner", startAt: start.addingTimeInterval(day))
        )
        let spanning = try await repository.create(
            EventDraft(
                spaceId: spaceId,
                title: "Trip",
                startAt: start.addingTimeInterval(-2 * day),
                endAt: start.addingTimeInterval(2 * day),
                kind: .trip
            )
        )
        _ = try await repository.create(
            EventDraft(spaceId: spaceId, title: "Far away", startAt: start.addingTimeInterval(30 * day))
        )

        let window = try await repository.events(
            spaceId: spaceId,
            from: start,
            to: start.addingTimeInterval(3 * day)
        )
        #expect(Set(window.map(\.id)) == Set([inside.id, spanning.id]))
        #expect(window.first?.startAt ?? start <= window.last?.startAt ?? start)
    }

    @Test func commentsAreCappedAndOrdered() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.events
        let event = try await repository.create(
            EventDraft(spaceId: world.space.id, title: "Anniversary", startAt: start, kind: .anniversary)
        )
        let first = try await repository.addComment(eventId: event.id, memberId: world.me.id, text: "Booked")
        let second = try await repository.addComment(
            eventId: event.id,
            memberId: world.partner.id,
            text: "Bring the camera"
        )
        let comments = try await repository.comments(eventId: event.id)
        #expect(comments.map(\.id) == [first.id, second.id])

        let long = String(repeating: "a", count: EventComment.maxLength + 1)
        await #expect(throws: CorbieError.invalidInput("comment is longer than 200")) {
            _ = try await repository.addComment(eventId: event.id, memberId: world.me.id, text: long)
        }

        try await repository.deleteComment(id: first.id)
        #expect(try await repository.comments(eventId: event.id).map(\.id) == [second.id])
    }

    @Test func deletingAnEventTakesItsComments() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.events
        let event = try await repository.create(
            EventDraft(spaceId: world.space.id, title: "Picnic", startAt: start)
        )
        _ = try await repository.addComment(eventId: event.id, memberId: world.me.id, text: "Blanket")
        try await repository.delete(id: event.id)
        #expect(try world.count("EventComment") == 0)
    }

    @Test func locationAndRemindersRoundTrip() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.events
        let event = try await repository.create(
            EventDraft(
                spaceId: world.space.id,
                title: "Concert",
                startAt: start,
                locationName: "Coliseu",
                address: "Rua das Portas de Santo Antao",
                latitude: 38.7169,
                longitude: -9.1399,
                reminderOffsets: [.dayBefore, .twoWeeksBefore],
                createdByMemberId: world.me.id
            )
        )
        let stored = try #require(try await repository.event(id: event.id))
        #expect(stored.hasLocation)
        #expect(stored.latitude == 38.7169)
        #expect(stored.reminderOffsets == [.dayBefore, .twoWeeksBefore])
    }

    @Test func multiDayIsDecidedInTheCalendarThatDrawsTheGrid() throws {
        var auckland = Calendar(identifier: .gregorian)
        auckland.timeZone = try #require(TimeZone(identifier: "Pacific/Auckland"))
        var formatter = ISO8601DateFormatter()
        formatter.timeZone = auckland.timeZone
        let lunchStart = try #require(formatter.date(from: "2026-03-10T10:00:00+13:00"))
        let lunchEnd = try #require(formatter.date(from: "2026-03-10T14:00:00+13:00"))
        let lunch = EventDTO(id: UUID(), title: "Lunch", startAt: lunchStart, endAt: lunchEnd)
        #expect(lunch.isMultiDay(calendar: auckland) == false)
        #expect(lunch.isMultiDay(calendar: .utc))

        let tripEnd = try #require(formatter.date(from: "2026-03-14T14:00:00+13:00"))
        let trip = EventDTO(id: UUID(), title: "Trip", startAt: lunchStart, endAt: tripEnd)
        #expect(trip.isMultiDay(calendar: auckland))
    }

    @Test func eventCannotEndBeforeItStarts() async throws {
        let world = try await TestWorld.make()
        await #expect(throws: CorbieError.invalidInput("event ends before it starts")) {
            _ = try await world.repositories.events.create(
                EventDraft(
                    spaceId: world.space.id,
                    title: "Broken",
                    startAt: start,
                    endAt: start.addingTimeInterval(-60)
                )
            )
        }
    }
}
