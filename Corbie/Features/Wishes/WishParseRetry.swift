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
