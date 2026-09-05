import CorbieCore
import Foundation

enum WishesFilter: String, CaseIterable, Hashable {
    case partner
    case me
    case all

    static func defaultSelection(isPaired: Bool) -> WishesFilter {
        isPaired ? .partner : .me
    }

    static func available(isPaired: Bool) -> [WishesFilter] {
        isPaired ? [.partner, .me, .all] : [.me, .all]
    }

    func resolved(isPaired: Bool) -> WishesFilter {
        WishesFilter.available(isPaired: isPaired).contains(self)
            ? self
            : WishesFilter.defaultSelection(isPaired: isPaired)
    }
}

struct WishesOwners: Equatable {
    var me: UUID?
    var partner: UUID?

    init(me: UUID? = nil, partner: UUID? = nil) {
        self.me = me
        self.partner = partner
    }
}

enum WishesGrouping {
    static func matches(_ wish: WishDTO, filter: WishesFilter, owners: WishesOwners) -> Bool {
        switch filter {
        case .all:
            return true
        case .me:
            guard let me = owners.me else { return false }
            return wish.ownerMemberId == me
        case .partner:
            guard let partner = owners.partner else { return false }
            return wish.ownerMemberId == partner
        }
    }

    static func wishes(_ wishes: [WishDTO], matching filter: WishesFilter, owners: WishesOwners) -> [WishDTO] {
        wishes.filter { matches($0, filter: filter, owners: owners) }
    }

    static func count(_ wishes: [WishDTO], matching filter: WishesFilter, owners: WishesOwners) -> Int {
        wishes.reduce(into: 0) { total, wish in
            total += matches(wish, filter: filter, owners: owners) ? 1 : 0
        }
    }
}
