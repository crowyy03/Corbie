import Foundation

public enum SupportedCurrencies {
    public static let codes = [
        "AUD", "BRL", "CAD", "CHF", "CNY", "CZK", "DKK", "EUR", "GBP", "HKD",
        "HUF", "IDR", "ILS", "INR", "ISK", "JPY", "KRW", "MXN", "MYR", "NOK",
        "NZD", "PHP", "PLN", "RON", "SEK", "SGD", "THB", "TRY", "USD", "ZAR"
    ]
    public static let fallbackCode = "USD"
    public static let common = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "HKD", "SGD"]

    public static func contains(_ raw: String?) -> Bool {
        guard let code = Money.currencyCode(raw) else { return false }
        return codes.contains(code)
    }

    public static func codeOrFallback(_ raw: String?) -> String {
        guard let code = Money.currencyCode(raw), codes.contains(code) else { return fallbackCode }
        return code
    }

    public static func defaultCode(for locale: Locale) -> String {
        guard let code = locale.currency?.identifier, contains(code) else { return fallbackCode }
        return code
    }

    public static func pickerGroups(for locale: Locale) -> [[String]] {
        let own = locale.currency.map(\.identifier).flatMap { contains($0) ? $0 : nil }
        let usual = common.filter { $0 != own }
        let rest = codes
            .filter { $0 != own && common.contains($0) == false }
            .sorted { name(of: $0, in: locale).localizedStandardCompare(name(of: $1, in: locale)) == .orderedAscending }
        return [own.map { [$0] } ?? [], usual, rest].filter { $0.isEmpty == false }
    }

    public static func name(of code: String, in locale: Locale) -> String {
        locale.localizedString(forCurrencyCode: code) ?? code
    }

    public static func label(of code: String, in locale: Locale) -> String {
        let name = name(of: code, in: locale)
        return name == code ? code : "\(name) (\(code))"
    }
}
