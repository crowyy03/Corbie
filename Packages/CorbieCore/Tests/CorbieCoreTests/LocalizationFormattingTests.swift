import Foundation
import Testing
@testable import CorbieCore

@Suite struct LocalizationFormattingTests {
    private let euros = Money(amount: Decimal(string: "91.5") ?? 0, currency: "EUR")

    @Test func euroSignFollowsTheAmountInGermanAndFrench() {
        let german = euros.formatted(locale: Locale(identifier: "de_DE"))
        let french = euros.formatted(locale: Locale(identifier: "fr_FR"))
        let american = euros.formatted(locale: Locale(identifier: "en_US"))

        #expect(german.hasSuffix("\u{20AC}"))
        #expect(french.hasSuffix("\u{20AC}"))
        #expect(american.hasPrefix("\u{20AC}"))
        #expect(german.hasPrefix("91,50"))
        #expect(french.hasPrefix("91,50"))
        #expect(american == "\u{20AC}91.50")
    }

    @Test func thousandsSeparatorFollowsTheLocale() {
        let amount = Money(amount: Decimal(2400), currency: "EUR")

        #expect(amount.formatted(locale: Locale(identifier: "de_DE")).hasPrefix("2.400"))
        #expect(amount.formatted(locale: Locale(identifier: "fr_FR")).hasPrefix("2\u{202F}400"))
        #expect(amount.formatted(locale: Locale(identifier: "en_US")) == "\u{20AC}2,400")
    }

    @Test func ordinalTextFollowsTheLocale() {
        #expect(ImportantDateText.ordinalText(2, locale: Locale(identifier: "en_US")) == "2nd")
        #expect(ImportantDateText.ordinalText(2, locale: Locale(identifier: "de_DE")) == "2.")
        #expect(ImportantDateText.ordinalText(2, locale: Locale(identifier: "fr_FR")) == "2e")
        #expect(ImportantDateText.ordinalText(1, locale: Locale(identifier: "fr_FR")) == "1er")
        #expect(ImportantDateText.ordinalText(2, locale: Locale(identifier: "es_ES")) == "2.\u{BA}")
        #expect(ImportantDateText.ordinalText(2, locale: Locale(identifier: "it_IT")) == "2\u{BA}")
    }

    @Test func euroSignFollowsTheAmountInSpanishAndItalian() {
        let spanish = euros.formatted(locale: Locale(identifier: "es_ES"))
        let italian = euros.formatted(locale: Locale(identifier: "it_IT"))

        #expect(spanish.hasSuffix("\u{20AC}"))
        #expect(italian.hasSuffix("\u{20AC}"))
        #expect(spanish.hasPrefix("91,50"))
        #expect(italian.hasPrefix("91,50"))
    }

    @Test func aWholeAmountDropsTheDecimals() {
        let amount = Money(amount: Decimal(120), currency: "EUR")

        #expect(amount.formatted(locale: Locale(identifier: "de_DE")) == "120\u{A0}\u{20AC}")
        #expect(amount.formatted(locale: Locale(identifier: "en_US")) == "\u{20AC}120")
    }

    @Test func aCurrencyWithoutDecimalsKeepsItsOwnDigits() {
        let yen = Money(amount: Decimal(2400), currency: "JPY")

        #expect(yen.formatted(locale: Locale(identifier: "de_DE")).hasPrefix("2.400"))
        #expect(yen.formatted(locale: Locale(identifier: "en_US")).contains("2,400"))
        #expect(yen.approximate(locale: Locale(identifier: "en_US")).hasPrefix("\u{2248} "))
    }

    @Test func shortDateLeadsWithTheDayOutsideAmericanEnglish() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin") ?? .gmt
        let day = calendar.date(from: DateComponents(year: 2026, month: 9, day: 6)) ?? Date()

        for identifier in ["de_DE", "fr_FR", "es_ES", "it_IT"] {
            let text = RelativeDateText(locale: Locale(identifier: identifier), calendar: calendar)
                .dueText(for: day, now: day)
            #expect(text.hasPrefix("6"), "\(identifier): \(text)")
        }

        let american = RelativeDateText(locale: Locale(identifier: "en_US"), calendar: calendar)
            .dueText(for: day, now: day)
        #expect(american.hasPrefix("6") == false, "\(american)")
        #expect(american.contains("6"))
    }

    @Test func firstWeekdayFollowsTheLocale() {
        var american = Calendar(identifier: .gregorian)
        american.locale = Locale(identifier: "en_US")
        var german = Calendar(identifier: .gregorian)
        german.locale = Locale(identifier: "de_DE")

        #expect(american.firstWeekday == 1)
        #expect(german.firstWeekday == 2)

        for identifier in ["fr_FR", "es_ES", "it_IT"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.locale = Locale(identifier: identifier)
            #expect(calendar.firstWeekday == 2, "\(identifier)")
        }
    }
}
