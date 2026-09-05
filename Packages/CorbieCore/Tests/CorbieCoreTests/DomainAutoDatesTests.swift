import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainAutoDatesTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "Europe/Berlin")
    private var provider: AutoDatesProvider { AutoDatesProvider(calendar: calendar) }

    private func space(togetherSince: String?, weddingDate: String? = nil) -> SpaceDTO {
        SpaceDTO(
            id: UUID(),
            togetherSince: togetherSince.map { DomainClock.date($0, in: calendar) },
            weddingDate: weddingDate.map { DomainClock.date($0, in: calendar) }
        )
    }

    @Test func anniversaryCarriesTheOrdinalYear() {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let dates = provider.autoDates(
            space: space(togetherSince: "2024-10-12", weddingDate: "2025-05-30"),
            members: [],
            people: [],
            now: now
        )
        let anniversary = dates.first { $0.kind == .anniversary }
        #expect(DomainClock.text(anniversary?.date ?? Date(), in: calendar) == "2026-10-12 00:00")
        #expect(anniversary?.years == 2)
        let wedding = dates.first { $0.kind == .wedding }
        #expect(DomainClock.text(wedding?.date ?? Date(), in: calendar) == "2027-05-30 00:00")
        #expect(wedding?.years == 2)
    }

    @Test func theFirstAnniversaryIsAYearAfterTheStart() {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let dates = provider.autoDates(space: space(togetherSince: "2026-09-05"), members: [], people: [], now: now)
        let anniversary = dates.first { $0.kind == .anniversary }
        #expect(DomainClock.text(anniversary?.date ?? Date(), in: calendar) == "2027-09-05 00:00")
        #expect(anniversary?.years == 1)
    }

    @Test func todaysAnniversaryStillCounts() {
        let now = DomainClock.date("2026-10-12 18:00", in: calendar)
        let dates = provider.autoDates(space: space(togetherSince: "2024-10-12"), members: [], people: [], now: now)
        let anniversary = dates.first { $0.kind == .anniversary }
        #expect(DomainClock.text(anniversary?.date ?? Date(), in: calendar) == "2026-10-12 00:00")
        #expect(provider.daysAway(from: now, to: anniversary?.date ?? Date()) == 0)
    }

    @Test func februaryTwentyNinthClampsToTheEndOfFebruary() {
        let leap = provider.nextYearlyDate(month: 2, day: 29, after: DomainClock.date("2028-01-05", in: calendar))
        #expect(DomainClock.text(leap ?? Date(), in: calendar) == "2028-02-29 00:00")
        let common = provider.nextYearlyDate(month: 2, day: 29, after: DomainClock.date("2027-01-05", in: calendar))
        #expect(DomainClock.text(common ?? Date(), in: calendar) == "2027-02-28 00:00")
        let anniversary = provider.nextAnniversary(
            of: DomainClock.date("2024-02-29", in: calendar),
            after: DomainClock.date("2027-01-05", in: calendar)
        )
        #expect(DomainClock.text(anniversary?.date ?? Date(), in: calendar) == "2027-02-28 00:00")
        #expect(anniversary?.years == 3)
    }

    @Test func birthdaysRollIntoTheNextYearOncePassed() {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let member = MemberDTO(id: UUID(), displayName: "Sofia", birthdayMonth: 3, birthdayDay: 14)
        let person = PersonDTO(id: UUID(), name: "Anna", birthdayMonth: 10, birthdayDay: 12, giftIdeaCount: 2)
        let dates = provider.autoDates(space: space(togetherSince: nil), members: [member], people: [person], now: now)
        let birthday = dates.first { $0.kind == .memberBirthday }
        #expect(DomainClock.text(birthday?.date ?? Date(), in: calendar) == "2027-03-14 00:00")
        #expect(birthday?.ownerMemberId == member.id)
        #expect(birthday?.name == "Sofia")
        #expect(birthday?.years == nil)
        let personBirthday = dates.first { $0.kind == .personBirthday }
        #expect(DomainClock.text(personBirthday?.date ?? Date(), in: calendar) == "2026-10-12 00:00")
        #expect(personBirthday?.personId == person.id)
    }

    @Test func identifiersAreStableAcrossYears() {
        let member = MemberDTO(id: UUID(), displayName: "Sofia", birthdayMonth: 3, birthdayDay: 14)
        let subject = space(togetherSince: "2024-10-12")
        let early = provider.autoDates(
            space: subject,
            members: [member],
            people: [],
            now: DomainClock.date("2026-01-05", in: calendar)
        )
        let late = provider.autoDates(
            space: subject,
            members: [member],
            people: [],
            now: DomainClock.date("2029-11-05", in: calendar)
        )
        #expect(early.map(\.id) == late.map(\.id))
        #expect(early.map(\.id).contains("auto.anniversary." + subject.id.uuidString))
        #expect(early.map(\.id).contains("auto.memberBirthday." + member.id.uuidString))
    }

    @Test func resultsAreSortedAndFilteredByHorizon() {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let soon = PersonDTO(id: UUID(), name: "Soon", birthdayMonth: 9, birthdayDay: 12)
        let later = PersonDTO(id: UUID(), name: "Later", birthdayMonth: 11, birthdayDay: 2)
        let subject = space(togetherSince: "2024-09-08")
        let all = provider.autoDates(space: subject, members: [], people: [soon, later], now: now)
        #expect(all.map(\.name) == [nil, "Soon", "Later"])
        let upcoming = provider.upcoming(space: subject, members: [], people: [soon, later], now: now, within: 14)
        #expect(upcoming.map(\.name) == [nil, "Soon"])
    }

    @Test func peopleWithoutABirthdayAreIgnored() {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let person = PersonDTO(id: UUID(), name: "Anna")
        let member = MemberDTO(id: UUID(), displayName: "Sofia")
        let dates = provider.autoDates(space: space(togetherSince: nil), members: [member], people: [person], now: now)
        #expect(dates.isEmpty)
    }
}
