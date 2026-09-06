import Foundation
import Testing
@testable import CorbieCore

@Suite struct MemberAndPeopleTests {
    @Test func upsertKeepsOneMemberPerAppleUser() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.members
        let again = try await repository.upsertCurrentMember(
            appleUserId: "apple-me",
            spaceId: world.space.id,
            draft: MemberDraft(displayName: "Ilya V", colorKey: "fog")
        )
        #expect(again.id == world.me.id)
        #expect(again.displayName == "Ilya V")
        #expect(again.colorKey == "fog")
        #expect(try await repository.members(spaceId: world.space.id).count == 2)
    }

    @Test func partnerIsTheOtherMember() async throws {
        let world = try await TestWorld.make()
        let partner = try await world.repositories.members.partner(of: world.me.id, spaceId: world.space.id)
        #expect(partner?.id == world.partner.id)
    }

    @Test func prefsDefaultToEveryNotificationOn() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.members
        #expect(world.me.notificationPrefs == .allEnabled)

        var prefs = NotificationPrefs.allEnabled
        prefs.partnerAddedWish = false
        prefs.voteUpdates = false
        let saved = try await repository.updatePrefs(memberId: world.me.id, prefs: prefs)
        #expect(saved.notificationPrefs.partnerAddedWish == false)
        #expect(saved.notificationPrefs.voteUpdates == false)
        #expect(saved.notificationPrefs.taskAssigned)
    }

    @Test func profileAndBirthdayRoundTrip() async throws {
        let world = try await TestWorld.make()
        var member = world.me
        member.displayName = "Ilya"
        member.birthdayMonth = 6
        member.birthdayDay = 20
        let saved = try await world.repositories.members.update(member)
        #expect(saved.hasBirthday)
        #expect(saved.birthdayMonth == 6)
        #expect(saved.birthdayDay == 20)
    }

    @Test func lastSeenIsRecorded() async throws {
        let world = try await TestWorld.make()
        let at = Date(timeIntervalSince1970: 1_757_000_000)
        try await world.repositories.members.touchLastSeen(memberId: world.me.id, at: at)
        let stored = try #require(try await world.repositories.members.member(id: world.me.id))
        #expect(stored.lastSeenAt == at)
    }

    @Test func peopleCarryGiftIdeas() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.people
        let person = try await repository.create(
            PersonDraft(
                spaceId: world.space.id,
                name: "Anna",
                relation: "Mom",
                birthdayMonth: 3,
                birthdayDay: 14,
                ownerMemberId: world.partner.id
            )
        )
        #expect(person.hasBirthday)

        var idea = try await repository.addGiftIdea(
            personId: person.id,
            draft: GiftIdeaDraft(title: "Ceramic mug", price: 24, currency: "EUR")
        )
        let withIdea = try #require(try await repository.person(id: person.id))
        #expect(withIdea.giftIdeaCount == 1)
        #expect(withIdea.hasPickedGift == false)

        idea.isDone = true
        _ = try await repository.updateGiftIdea(idea)
        let picked = try #require(try await repository.person(id: person.id))
        #expect(picked.hasPickedGift)

        try await repository.deleteGiftIdea(id: idea.id)
        #expect(try await repository.giftIdeas(personId: person.id).isEmpty)
    }

    @Test func aBirthdayYearIsOptionalAndSurvivesAnEdit() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.people
        var person = try await repository.create(
            PersonDraft(spaceId: world.space.id, name: "Anna", birthdayMonth: 9, birthdayDay: 12)
        )
        #expect(person.birthdayYear == nil)
        person.birthdayYear = 1992
        let saved = try await repository.update(person)
        #expect(saved.birthdayYear == 1992)
        let stored = try #require(try await repository.person(id: person.id))
        #expect(stored.birthdayYear == 1992)
    }

    @Test func peopleCarryTheirOwnDates() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.people
        let person = try await repository.create(PersonDraft(spaceId: world.space.id, name: "Anna"))
        var wedding = try await repository.addDate(
            personId: person.id,
            draft: PersonDateDraft(title: "wedding day", month: 6, day: 4, year: 2019)
        )
        _ = try await repository.addDate(
            personId: person.id,
            draft: PersonDateDraft(title: "name day", month: 2, day: 3, remindersEnabled: false)
        )
        let dates = try await repository.dates(personId: person.id)
        #expect(dates.map(\.title) == ["name day", "wedding day"])
        #expect(dates[0].remindersEnabled == false)
        #expect(dates[0].year == nil)
        #expect(dates[1].year == 2019)

        wedding.title = "anniversary"
        wedding.remindersEnabled = false
        let saved = try await repository.updateDate(wedding)
        #expect(saved.title == "anniversary")
        #expect(saved.remindersEnabled == false)

        let carried = try #require(try await repository.person(id: person.id))
        #expect(carried.dates.map(\.title) == ["name day", "anniversary"])

        try await repository.deleteDate(id: wedding.id)
        #expect(try await repository.dates(personId: person.id).map(\.title) == ["name day"])
    }

    @Test func deletingAPersonRemovesTheirDates() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.people
        let person = try await repository.create(PersonDraft(spaceId: world.space.id, name: "Temp"))
        _ = try await repository.addDate(personId: person.id, draft: PersonDateDraft(title: "moving day", month: 4, day: 1))
        try await repository.delete(id: person.id)
        #expect(try world.count("PersonDate") == 0)
    }

    @Test func aDateWithoutATitleOrWithAnImpossibleDayIsRejected() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.people
        let person = try await repository.create(PersonDraft(spaceId: world.space.id, name: "Anna"))
        await #expect(throws: CorbieError.invalidInput("person date title is empty")) {
            _ = try await repository.addDate(personId: person.id, draft: PersonDateDraft(title: "  ", month: 4, day: 1))
        }
        await #expect(throws: CorbieError.invalidInput("birthday 13/40 is out of range")) {
            _ = try await repository.addDate(personId: person.id, draft: PersonDateDraft(title: "Nope", month: 13, day: 40))
        }
        await #expect(throws: CorbieError.invalidInput("year 12345 is out of range")) {
            _ = try await repository.addDate(
                personId: person.id,
                draft: PersonDateDraft(title: "Nope", month: 4, day: 1, year: 12345)
            )
        }
    }

    @Test func birthdayOutOfRangeIsRejected() async throws {
        let world = try await TestWorld.make()
        await #expect(throws: CorbieError.invalidInput("birthday 13/40 is out of range")) {
            _ = try await world.repositories.people.create(
                PersonDraft(spaceId: world.space.id, name: "Nobody", birthdayMonth: 13, birthdayDay: 40)
            )
        }
    }

    @Test func deletingAPersonRemovesTheirIdeas() async throws {
        let world = try await TestWorld.make()
        let repository = world.repositories.people
        let person = try await repository.create(PersonDraft(spaceId: world.space.id, name: "Temp"))
        _ = try await repository.addGiftIdea(personId: person.id, draft: GiftIdeaDraft(title: "Socks"))
        try await repository.delete(id: person.id)
        #expect(try world.count("GiftIdea") == 0)
    }

    @Test func deletingAPersonLetsGoOfTheirBirthdayEvent() async throws {
        let world = try await TestWorld.make()
        let person = try await world.repositories.people.create(
            PersonDraft(spaceId: world.space.id, name: "Anna", birthdayMonth: 4, birthdayDay: 12)
        )
        let event = try await world.repositories.events.create(
            EventDraft(
                spaceId: world.space.id,
                title: "Anna",
                startAt: Date(),
                kind: .birthday,
                personId: person.id
            )
        )
        try await world.repositories.people.delete(id: person.id)
        let stored = try #require(try await world.repositories.events.event(id: event.id))
        #expect(stored.personId == nil)
    }

    @Test func onlyTheHashOfTheAppleIdentifierIsStored() async throws {
        let world = try await TestWorld.make()
        let member = try #require(try await world.repositories.members.member(appleUserId: "apple-me"))
        #expect(member.appleUserHash == AppleUserHash.value("apple-me"))
        #expect(member.appleUserHash != "apple-me")
        #expect(member.id == world.me.id)
    }
}
