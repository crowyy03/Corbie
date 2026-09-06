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

    @Test func firstWeekdayFollowsTheLocale() {
        var american = Calendar(identifier: .gregorian)
        american.locale = Locale(identifier: "en_US")
        var german = Calendar(identifier: .gregorian)
        german.locale = Locale(identifier: "de_DE")

        #expect(american.firstWeekday == 1)
        #expect(german.firstWeekday == 2)
    }
}
