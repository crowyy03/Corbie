import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainImportantDatesTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "Europe/Berlin")

    private func space(togetherSince: String?, weddingDate: String? = nil) -> SpaceDTO {
        SpaceDTO(
            id: UUID(),
            togetherSince: togetherSince.map { DomainClock.date($0, in: calendar) },
            weddingDate: weddingDate.map { DomainClock.date($0, in: calendar) }
        )
    }

    @Test func daysTogetherCountsWholeElapsedDays() {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        #expect(ImportantDates.daysTogether(space: space(togetherSince: "2025-06-03"), now: now, calendar: calendar) == 459)
        #expect(ImportantDates.daysTogether(space: space(togetherSince: "2026-09-05"), now: now, calendar: calendar) == 0)
        #expect(ImportantDates.daysTogether(space: space(togetherSince: nil), now: now, calendar: calendar) == nil)
    }

    @Test func daysTogetherIgnoresTheTimeOfDay() {
        let space = space(togetherSince: "2026-09-01 23:30")
        let now = DomainClock.date("2026-09-05 00:10", in: calendar)
        #expect(ImportantDates.daysTogether(space: space, now: now, calendar: calendar) == 4)
    }

    @Test func theNearestOfTheFourKindsWins() {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let viewer = MemberDTO(id: UUID(), displayName: "Ilya", birthdayMonth: 9, birthdayDay: 6)
        let partner = MemberDTO(id: UUID(), displayName: "Sofia", birthdayMonth: 12, birthdayDay: 1)
        let next = ImportantDates.nextImportantDate(
            space: space(togetherSince: "2024-10-12", weddingDate: "2025-11-01"),
            members: [viewer, partner],
            people: [],
            pinnedEvents: [],
            now: now,
            viewerMemberId: viewer.id,
            calendar: calendar
        )
        #expect(next?.kind == .anniversary)
        #expect(next?.ordinal == 2)
        #expect(next?.daysAway == 37)
    }

    @Test func theViewerOwnBirthdayIsNotAPartnerBirthday() {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let viewer = MemberDTO(id: UUID(), displayName: "Ilya", birthdayMonth: 9, birthdayDay: 6)
        let partner = MemberDTO(id: UUID(), displayName: "Sofia", birthdayMonth: 12, birthdayDay: 1)
        let dates = ImportantDates.upcomingImportantDates(
            space: space(togetherSince: nil),
            members: [viewer, partner],
            people: [],
            pinnedEvents: [],
            now: now,
            viewerMemberId: viewer.id,
            calendar: calendar
        )
        #expect(dates.count == 1)
        #expect(dates[0].kind == .partnerBirthday)
        #expect(dates[0].personName == "Sofia")
    }

    @Test func aPinnedEventCanBeTheNearestDate() {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let partner = MemberDTO(id: UUID(), displayName: "Sofia", birthdayMonth: 12, birthdayDay: 1)
        let event = EventDTO(
            id: UUID(),
            title: "Concert",
            startAt: DomainClock.date("2026-09-19 20:00", in: calendar)
        )
        let next = ImportantDates.nextImportantDate(
            space: space(togetherSince: "2024-10-12"),
            members: [partner],
            people: [],
            pinnedEvents: [event],
            now: now,
            calendar: calendar
        )
        #expect(next?.kind == .customEvent)
        #expect(next?.eventId == event.id)
        #expect(next?.personName == "Concert")
        #expect(next?.daysAway == 14)
    }

    @Test func aPinnedBirthdayEventTakesItsNameFromPeople() {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let person = PersonDTO(id: UUID(), name: "Anna", birthdayMonth: 9, birthdayDay: 12)
        let event = EventDTO(
            id: UUID(),
            title: "Anna's birthday",
            startAt: DomainClock.date("2026-09-12", in: calendar),
            kind: .birthday,
            personId: person.id
        )
        let next = ImportantDates.nextImportantDate(
            space: space(togetherSince: nil),
            members: [],
            people: [person],
            pinnedEvents: [event],
            now: now,
            calendar: calendar
        )
        #expect(next?.personName == "Anna")
    }

    @Test func eventsInThePastAreIgnored() {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let past = EventDTO(id: UUID(), title: "Gone", startAt: DomainClock.date("2026-09-01", in: calendar))
        let next = ImportantDates.nextImportantDate(
            space: space(togetherSince: nil),
            members: [],
            people: [],
            pinnedEvents: [past],
            now: now,
            calendar: calendar
        )
        #expect(next == nil)
    }
}
