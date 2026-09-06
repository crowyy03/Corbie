import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainRadarTests {
    private let calendar = DomainClock.calendar(locale: "en_US", timeZone: "Europe/Berlin")
    private var service: RadarService { RadarService(calendar: calendar) }
    private let now = DomainClock.date("2026-09-05 12:00", in: DomainClock.calendar(timeZone: "Europe/Berlin"))

    private func input(
        people: [PersonDTO] = [],
        partnerWishes: [WishDTO] = [],
        togetherSince: String? = nil,
        partnerBirthday: (month: Int, day: Int)? = nil
    ) -> RadarInput {
        let viewer = MemberDTO(id: UUID(), displayName: "Ilya", birthdayMonth: 1, birthdayDay: 2)
        let partner = MemberDTO(
            id: UUID(),
            displayName: "Sofia",
            birthdayMonth: partnerBirthday?.month,
            birthdayDay: partnerBirthday?.day
        )
        return RadarInput(
            space: SpaceDTO(
                id: UUID(),
                togetherSince: togetherSince.map { DomainClock.date($0, in: calendar) }
            ),
            members: [viewer, partner],
            people: people,
            partnerWishes: partnerWishes,
            viewerMemberId: viewer.id
        )
    }

    @Test func onlyDatesInsideTheHorizonProduceLines() {
        let soon = PersonDTO(id: UUID(), name: "Anna", birthdayMonth: 9, birthdayDay: 12, giftIdeaCount: 3)
        let far = PersonDTO(id: UUID(), name: "Mark", birthdayMonth: 11, birthdayDay: 2, giftIdeaCount: 1)
        let lines = service.lines(input(people: [soon, far]), now: now)
        #expect(lines.map(\.name) == ["Anna"])
        #expect(lines[0].daysAway == 7)
        #expect(lines[0].status == RadarStatus(ideasCount: 3, giftPicked: false))
        #expect(lines[0].route == .person(soon.id))
    }

    @Test func aDoneGiftIdeaMarksThePersonAsCovered() {
        let person = PersonDTO(
            id: UUID(),
            name: "Anna",
            birthdayMonth: 9,
            birthdayDay: 12,
            giftIdeaCount: 3,
            hasPickedGift: true
        )
        let lines = service.lines(input(people: [person]), now: now)
        #expect(lines[0].status == RadarStatus(ideasCount: 3, giftPicked: true))
    }

    @Test func thePartnerBirthdayUsesTheirOpenWishes() {
        let wishes = [
            WishDTO(id: UUID(), title: "Apron", priority: .must),
            WishDTO(id: UUID(), title: "Filters", priority: .want),
            WishDTO(
                id: UUID(),
                title: "Mug",
                isFulfilled: true,
                fulfilledAt: DomainClock.date("2026-08-20", in: calendar)
            )
        ]
        let lines = service.lines(
            input(partnerWishes: wishes, partnerBirthday: (month: 9, day: 15)),
            now: now
        )
        #expect(lines.count == 1)
        #expect(lines[0].kind == .memberBirthday)
        #expect(lines[0].status == RadarStatus(ideasCount: 2, giftPicked: true))
        #expect(lines[0].route == .us)
    }

    @Test func aGiftOlderThanThirtyDaysDoesNotCount() {
        let wishes = [
            WishDTO(id: UUID(), title: "Apron"),
            WishDTO(
                id: UUID(),
                title: "Mug",
                isFulfilled: true,
                fulfilledAt: DomainClock.date("2026-07-01", in: calendar)
            )
        ]
        let lines = service.lines(
            input(partnerWishes: wishes, partnerBirthday: (month: 9, day: 15)),
            now: now
        )
        #expect(lines[0].status == RadarStatus(ideasCount: 1, giftPicked: false))
    }

    @Test func theAnniversaryAlsoAppearsOnTheRadar() {
        let lines = service.lines(input(togetherSince: "2024-09-14"), now: now)
        #expect(lines.map(\.kind) == [.anniversary])
        #expect(lines[0].autoDate.years == 2)
    }

    @Test func theViewerOwnBirthdayIsNotOnTheRadar() {
        let viewer = MemberDTO(id: UUID(), displayName: "Ilya", birthdayMonth: 9, birthdayDay: 10)
        let partner = MemberDTO(id: UUID(), displayName: "Sofia")
        let subject = RadarInput(
            space: SpaceDTO(id: UUID()),
            members: [viewer, partner],
            viewerMemberId: viewer.id
        )
        #expect(service.lines(subject, now: now).isEmpty)
    }

    @Test func schedulingCoversTheYearAndSkipsDatesInsideTheLeadWindow() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(client: center, calendar: calendar)
        let soon = PersonDTO(id: UUID(), name: "Anna", birthdayMonth: 9, birthdayDay: 12, giftIdeaCount: 3)
        let far = PersonDTO(id: UUID(), name: "Mark", birthdayMonth: 11, birthdayDay: 2, giftIdeaCount: 1)
        let scheduled = try await service.schedule(
            input(people: [soon, far]),
            prefs: .allEnabled,
            now: now,
            using: scheduler
        )
        #expect(scheduled.count == 1)
        #expect(scheduled[0].id == NotificationIdentifier.dateRadar(
            autoDateId: AutoDatesProvider.identifier(kind: .personBirthday, owner: far.id)
        ))
        #expect(DomainClock.text(scheduled[0].fireDate, in: calendar) == "2026-10-19 10:00")
        #expect(scheduled[0].content.arguments == ["Mark", "14", "1"])
    }

    @Test func aPersonDateSitsOnTheRadarLikeABirthday() {
        let person = PersonDTO(
            id: UUID(),
            name: "Anna",
            giftIdeaCount: 3,
            dates: [PersonDateDTO(id: UUID(), title: "wedding day", month: 9, day: 12)]
        )
        let lines = service.lines(input(people: [person]), now: now)
        #expect(lines.map(\.name) == ["Anna: wedding day"])
        #expect(lines[0].kind == .event)
        #expect(lines[0].daysAway == 7)
        #expect(lines[0].status == RadarStatus(ideasCount: 3, giftPicked: false))
        #expect(lines[0].route == .person(person.id))
    }

    @Test func aPickedGiftCoversEveryDateOfThatPerson() {
        let person = PersonDTO(
            id: UUID(),
            name: "Anna",
            birthdayMonth: 9,
            birthdayDay: 12,
            giftIdeaCount: 2,
            hasPickedGift: true,
            dates: [PersonDateDTO(id: UUID(), title: "wedding day", month: 9, day: 14)]
        )
        let lines = service.lines(input(people: [person]), now: now)
        #expect(lines.count == 2)
        #expect(lines.allSatisfy { $0.status == RadarStatus(ideasCount: 2, giftPicked: true) })
    }

    @Test func aDateWithRemindersOffKeepsItsLineAndLosesItsNotification() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(client: center, calendar: calendar)
        let quiet = PersonDateDTO(id: UUID(), title: "name day", month: 11, day: 2, remindersEnabled: false)
        let loud = PersonDateDTO(id: UUID(), title: "moving day", month: 11, day: 3)
        let person = PersonDTO(id: UUID(), name: "Anna", giftIdeaCount: 1, dates: [quiet, loud])
        let lines = service.lines(input(people: [person]), now: now, within: RadarService.schedulingHorizonDays)
        #expect(lines.map(\.name) == ["Anna: name day", "Anna: moving day"])
        let scheduled = try await service.schedule(
            input(people: [person]),
            prefs: .allEnabled,
            now: now,
            using: scheduler
        )
        #expect(scheduled.map(\.content.arguments) == [["Anna: moving day", "14", "1"]])
    }

    @Test func radarSchedulingRespectsThePreference() async throws {
        let center = FakeNotificationCenter()
        let scheduler = NotificationScheduler(client: center, calendar: calendar)
        var prefs = NotificationPrefs.allEnabled
        prefs.dateRadar = false
        let person = PersonDTO(id: UUID(), name: "Mark", birthdayMonth: 11, birthdayDay: 2, giftIdeaCount: 1)
        let scheduled = try await service.schedule(
            input(people: [person]),
            prefs: prefs,
            now: now,
            using: scheduler
        )
        #expect(scheduled.isEmpty)
        #expect(await center.requests.isEmpty)
    }
}
