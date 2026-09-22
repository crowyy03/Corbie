import Foundation

public enum SupportedCurrencies {
    public static let codes = ["USD", "EUR", "GBP", "CAD", "AUD", "NZD", "JPY", "CHF"]
    public static let defaultCode = "USD"

    public static func contains(_ raw: String?) -> Bool {
        guard let code = Money.currencyCode(raw) else { return false }
        return codes.contains(code)
    }

    public static func codeOrDefault(_ raw: String?) -> String {
        guard let code = Money.currencyCode(raw), codes.contains(code) else { return defaultCode }
        return code
    }
}
