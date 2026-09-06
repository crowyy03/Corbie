import Foundation
import Testing
@testable import CorbieCore

@Suite struct DomainWidgetTextTests {
    private let calendar = DomainClock.calendar(timeZone: "UTC")
    private let locale = Locale(identifier: "en_US")

    @Test func aPickedGiftWinsOverSavedIdeas() {
        let text = RadarText(daysAway: 14, status: RadarStatus(ideasCount: 3, giftPicked: true))
        #expect(text.gift == .picked)
        #expect(text.daysAway == 14)
    }

    @Test func savedIdeasAreCountedWhenNothingIsPicked() {
        let text = RadarText(daysAway: 5, status: RadarStatus(ideasCount: 3, giftPicked: false))
        #expect(text.gift == .ideas(3))
    }

    @Test func noIdeasAndNoGiftIsEmpty() {
        let text = RadarText(daysAway: 0, status: RadarStatus(ideasCount: 0, giftPicked: false))
        #expect(text.gift == .nothing)
    }

    @Test func aRadarLineCarriesItsDaysAndStatus() {
        let line = RadarLine(
            autoDate: AutoDate(
                id: "person.birthday",
                kind: .personBirthday,
                date: DomainClock.date("2026-09-19", in: calendar),
                name: "Anna"
            ),
            daysAway: 14,
            status: RadarStatus(ideasCount: 2, giftPicked: false)
        )
        let text = RadarText(line)
        #expect(text.daysAway == 14)
        #expect(text.gift == .ideas(2))
    }

    @Test func ordinalsFollowTheLocale() {
        #expect(ImportantDateText.ordinalText(1, locale: locale) == "1st")
        #expect(ImportantDateText.ordinalText(2, locale: locale) == "2nd")
        #expect(ImportantDateText.ordinalText(3, locale: locale) == "3rd")
        #expect(ImportantDateText.ordinalText(11, locale: locale) == "11th")
    }

    @Test func aShortDateDropsTheYearInsideThisYear() {
        let now = DomainClock.date("2026-09-05 12:00", in: calendar)
        let sameYear = DomainClock.date("2026-10-12", in: calendar)
        let nextYear = DomainClock.date("2027-01-04", in: calendar)
        #expect(WidgetDateLabel.shortDate(sameYear, now: now, locale: locale, calendar: calendar) == "Oct 12")
        #expect(
            WidgetDateLabel.shortDate(nextYear, now: now, locale: locale, calendar: calendar).contains("2027")
        )
    }

    @Test func everyWidgetDateKindMapsFromAnAutoDate() {
        #expect(WidgetDateKind(.anniversary) == .anniversary)
        #expect(WidgetDateKind(.wedding) == .wedding)
        #expect(WidgetDateKind(.memberBirthday) == .memberBirthday)
        #expect(WidgetDateKind(.personBirthday) == .personBirthday)
        #expect(WidgetDateKind(.event) == .event)
    }

    @Test func aPersonDateReadsAsTheNameAndTheTitle() {
        #expect(PersonDateText.label(person: "Anna", title: "wedding day", locale: locale) == "Anna: wedding day")
        #expect(PersonDateText.label(person: " Anna ", title: " wedding day ", locale: locale) == "Anna: wedding day")
        #expect(PersonDateText.label(person: "", title: "wedding day", locale: locale) == "wedding day")
        #expect(PersonDateText.label(person: "Anna", title: "", locale: locale) == "Anna")
        #expect(
            WidgetDateLabel.upcoming(kind: .event, title: "Anna: wedding day", locale: locale) == "Anna: wedding day"
        )
    }

    @Test func theAgeShowsUpOnlyWhenTheYearIsKnown() {
        #expect(PersonDateText.age(turning: 34, locale: locale) == "turns 34")
        #expect(PersonDateText.birthdayTitle(person: "Anna", ordinal: nil, locale: locale) == nil)
        #expect(PersonDateText.birthdayTitle(person: nil, ordinal: 34, locale: locale) == nil)
        #expect(PersonDateText.birthdayTitle(person: "Anna", ordinal: 0, locale: locale) == nil)
        let plain = WidgetDateLabel.upcoming(kind: .personBirthday, title: "Anna", locale: locale)
        #expect(plain.contains("34") == false)
    }

    @Test func aPriceWithoutAUsableCurrencyCodeHasNoText() {
        #expect(Money.make(amount: 48, currency: nil) == nil)
        #expect(Money.make(amount: 48, currency: "") == nil)
        #expect(Money.make(amount: 48, currency: "dollars") == nil)
        #expect(Money.make(amount: nil, currency: "USD") == nil)
        #expect(Money.make(amount: 48, currency: " usd ")?.formatted(locale: locale) == "$48")
    }
}
