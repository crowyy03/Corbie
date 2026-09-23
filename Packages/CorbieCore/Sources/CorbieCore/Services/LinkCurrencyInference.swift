import Foundation

public enum LinkCurrencyInference {
    public enum Source: String, Sendable {
        case path
        case host
    }

    public struct Match: Sendable, Equatable {
        public let currency: String
        public let source: Source
    }

    private enum Segment {
        case country(String)
        case language
        case other
    }

    private static let countriesByCurrency: [String: [String]] = [
        "USD": ["us"],
        "EUR": [
            "at", "be", "bg", "cy", "de", "ee", "es", "fi", "fr", "gr", "hr",
            "ie", "it", "lt", "lu", "lv", "mt", "nl", "pt", "si", "sk"
        ],
        "GBP": ["gb", "uk"],
        "CAD": ["ca"],
        "AUD": ["au"],
        "NZD": ["nz"],
        "JPY": ["jp"],
        "CHF": ["ch", "li"]
    ]

    static let currencyByCountry: [String: String] = Dictionary(
        uniqueKeysWithValues: countriesByCurrency.flatMap { currency, countries in
            countries.map { ($0, currency) }
        }
    )

    static let languages: Set<String> = [
        "ar", "be", "bg", "bs", "ca", "cs", "cy", "da", "de", "el", "en", "es", "et", "eu", "fa", "fi",
        "fr", "ga", "gl", "he", "hi", "hr", "hu", "id", "is", "it", "ja", "ko", "lb", "lt", "lv", "ms",
        "mt", "nb", "nl", "nn", "no", "pl", "pt", "ro", "ru", "si", "sk", "sl", "sr", "sv", "th", "tr",
        "uk", "vi", "zh"
    ]

    public static func match(for url: URL) -> Match? {
        let hostCountry = country(ofHost: url.host())
        if let pathCountry = pathCountry(of: url, hostNamesACountry: hostCountry != nil) {
            return currencyByCountry[pathCountry].map { Match(currency: $0, source: .path) }
        }
        guard let hostCountry, let currency = currencyByCountry[hostCountry] else { return nil }
        return Match(currency: currency, source: .host)
    }

    private static func country(ofHost host: String?) -> String? {
        guard let label = host?.lowercased().split(separator: ".").last, isTwoLetters(label) else { return nil }
        return String(label)
    }

    private static func pathCountry(of url: URL, hostNamesACountry: Bool) -> String? {
        let segments = url.path(percentEncoded: false).split(separator: "/").prefix(2)
        for segment in segments {
            switch classify(segment.lowercased(), hostNamesACountry: hostNamesACountry) {
            case .country(let code): return code
            case .language: continue
            case .other: return nil
            }
        }
        return nil
    }

    private static func classify(_ segment: String, hostNamesACountry: Bool) -> Segment {
        let parts = segment.split(whereSeparator: { $0 == "-" || $0 == "_" }).map(String.init)
        if parts.count == 2 {
            guard parts.allSatisfy(isTwoLetters) else { return .other }
            if languages.contains(parts[0]) { return .country(parts[1]) }
            if currencyByCountry[parts[0]] != nil, languages.contains(parts[1]) { return .country(parts[0]) }
            return .other
        }
        guard isTwoLetters(segment) else { return .other }
        switch (currencyByCountry[segment] != nil, languages.contains(segment)) {
        case (true, false): return .country(segment)
        case (true, true): return hostNamesACountry ? .language : .country(segment)
        case (false, true): return .language
        case (false, false): return .other
        }
    }

    private static func isTwoLetters<Text: StringProtocol>(_ text: Text) -> Bool {
        text.count == 2 && text.allSatisfy { $0.isASCII && $0.isLetter }
    }
}
