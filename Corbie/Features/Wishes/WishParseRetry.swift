import CorbieCore
import Foundation

enum WishParseRetry {
    static let batchLimit = 5

    static func candidates(
        in wishes: [WishDTO],
        attempted: Set<UUID>,
        isOnline: Bool,
        limit: Int = WishParseRetry.batchLimit
    ) -> [WishDTO] {
        guard isOnline, limit > 0 else { return [] }
        let pending = wishes.filter { wish in
            wish.needsParse
                && wish.isFulfilled == false
                && attempted.contains(wish.id) == false
                && LinkParser.normalize(wish.url ?? "") != nil
        }
        return Array(pending.prefix(limit))
    }
}

enum WishParsedFill {
    static func merged(_ parsed: ParsedLink, into wish: WishDTO) -> WishDTO {
        var filled = wish
        filled.url = parsed.canonicalURL.absoluteString
        filled.source = parsed.source
        if filled.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let title = parsed.title {
            filled.title = title
        }
        if filled.price == nil, let price = parsed.price {
            filled.price = price
            filled.currency = WishPricing.currencyCode(parsed.currency) ?? filled.currency
        }
        if let imageURL = parsed.imageURL {
            filled.imageURL = imageURL.absoluteString
        }
        if filled.localImage == nil, let data = parsed.imageData {
            filled.localImage = data
        }
        filled.needsParse = false
        return filled
    }
}
