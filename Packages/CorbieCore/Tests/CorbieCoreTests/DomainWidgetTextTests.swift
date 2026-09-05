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
        #expect(WidgetDateLabel.ordinalText(1, locale: locale) == "1st")
        #expect(WidgetDateLabel.ordinalText(2, locale: locale) == "2nd")
        #expect(WidgetDateLabel.ordinalText(3, locale: locale) == "3rd")
        #expect(WidgetDateLabel.ordinalText(11, locale: locale) == "11th")
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
    }

    @Test func amountsFallBackToTheLocaleCurrencyWithoutACode() {
        #expect(WidgetAmountText.string(amount: nil, currency: "USD", locale: locale) == nil)
        #expect(WidgetAmountText.string(amount: 2400, currency: "USD", locale: locale) == "$2,400")
        #expect(WidgetAmountText.string(amount: 12.5, currency: "USD", locale: locale) == "$12.50")
    }
}
