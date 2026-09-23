import Foundation
import os

public enum WishLinkLog {
    public enum Reader: String, Sendable {
        case editor
        case shareExtension = "share"
        case backgroundRetry = "retry"
    }

    private static let log = Logger(subsystem: CorbieIdentifiers.bundleID, category: "wishes")

    public static func readEmpty(_ link: URL, parsed: ParsedLink, reader: Reader) {
        let host = link.host() ?? "none"
        let canonicalHost = parsed.canonicalURL.host() ?? "none"
        let price = parsed.price.map { String($0) } ?? "none"
        let currency = parsed.currency ?? "none"
        log.error(
            """
            link read empty host=\(host, privacy: .public) reader=\(reader.rawValue, privacy: .public) \
            got source=\(parsed.source.rawValue, privacy: .public) canonical=\(canonicalHost, privacy: .public) \
            price=\(price, privacy: .public) currency=\(currency, privacy: .public) title=none image=none
            """
        )
    }

    public static func priceInUnsupportedCurrency(_ link: URL, currency: String) {
        let host = link.host() ?? "none"
        log.notice(
            "link price left out host=\(host, privacy: .public) unsupported currency=\(currency, privacy: .public)"
        )
    }

    public static func priceCurrencyInferred(_ link: URL, page: URL, inferred: LinkCurrencyInference.Match) {
        let host = link.host() ?? "none"
        let canonicalHost = page.host() ?? "none"
        log.notice(
            """
            link price kept host=\(host, privacy: .public) canonical=\(canonicalHost, privacy: .public) \
            currency=none inferred=\(inferred.currency, privacy: .public) \
            from=\(inferred.source.rawValue, privacy: .public)
            """
        )
    }

    public static func priceWithoutCurrency(_ link: URL, page: URL) {
        let host = link.host() ?? "none"
        let canonicalHost = page.host() ?? "none"
        log.notice(
            """
            link price left out host=\(host, privacy: .public) canonical=\(canonicalHost, privacy: .public) \
            currency=none inferred=none
            """
        )
    }

    public static func failed(_ link: URL, error: any Error, reader: Reader) {
        let host = link.host() ?? "none"
        let reason = (error as? CorbieError)?.failureReason ?? error.localizedDescription
        log.error(
            """
            link read failed host=\(host, privacy: .public) reader=\(reader.rawValue, privacy: .public) \
            reason=\(reason, privacy: .public)
            """
        )
    }
}
