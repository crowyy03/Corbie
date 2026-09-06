import CorbieCore
import Foundation

enum WishPricing {
    static func money(for wish: WishDTO) -> Money? {
        guard let price = wish.price, price > 0 else { return nil }
        return Money.make(amount: price, currency: wish.currency)
    }

    static func approximate(_ money: Money, in displayCurrency: String, rates: FXRates?) -> Money? {
        guard let target = Money.currencyCode(displayCurrency), target != money.currency else { return nil }
        guard let rates, rates.base == money.currency, let rate = rates.rate(to: target) else { return nil }
        return Money(amount: FXMath.convert(amount: money.amount, rate: rate), currency: target)
    }

    static func currenciesNeedingRates(_ wishes: [WishDTO], displayCurrency: String) -> Set<String> {
        guard let display = Money.currencyCode(displayCurrency) else { return [] }
        return Set(wishes.compactMap { money(for: $0)?.currency }.filter { $0 != display })
    }

    static func amount(from text: String, locale: Locale = .current) -> Double? {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.isEmpty == false else { return nil }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        if let number = formatter.number(from: cleaned) { return number.doubleValue }
        return Double(cleaned.replacingOccurrences(of: ",", with: "."))
    }

    static func text(from amount: Double, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        formatter.usesGroupingSeparator = false
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? ""
    }
}
