import CorbieCore
import Foundation

struct ChoreTrade: Identifiable, Equatable {
    let id: UUID
    let title: String
    let line: String
    let stamp: String
}

struct ChoreShare: Identifiable, Equatable {
    let id: String
    let title: String
    let chores: [String]
}

struct ChoreSplitPresentation {
    static let maximumTrades = 4

    let headline: String
    let footer: String
    let trades: [ChoreTrade]
    let lists: [ChoreShare]

    init(
        set: ChoreSetDTO,
        viewerMemberId: UUID?,
        partnerMemberId: UUID?,
        partnerName: String,
        copy: ChoreCopy = ChoreCopy()
    ) {
        headline = String(localized: "chore.reveal.headline")
        footer = String(localized: "chore.reveal.footer")
        let decided = set.includedItems.filter { $0.assignment != nil }
        trades = ChoreSplitPresentation.trades(
            in: decided,
            viewerMemberId: viewerMemberId,
            partnerMemberId: partnerMemberId,
            partnerName: partnerName,
            copy: copy
        )
        lists = ChoreSplitPresentation.lists(
            in: decided,
            viewerMemberId: viewerMemberId,
            partnerName: partnerName
        )
    }

    var everyLine: [String] {
        [headline, footer]
            + trades.flatMap { [$0.title, $0.line, $0.stamp] }
            + lists.flatMap { [$0.title] + $0.chores }
    }

    var rotatingCount: Int {
        lists.first { $0.id == ChoreShareKind.rotating.rawValue }?.chores.count ?? 0
    }

    private static func trades(
        in items: [ChoreItemDTO],
        viewerMemberId: UUID?,
        partnerMemberId: UUID?,
        partnerName: String,
        copy: ChoreCopy
    ) -> [ChoreTrade] {
        items
            .filter { item in
                guard let assignment = item.assignment else { return false }
                return assignment.result == .member && assignment.scoreGap > 0
            }
            .sorted { left, right in
                let leftGap = left.assignment?.scoreGap ?? 0
                let rightGap = right.assignment?.scoreGap ?? 0
                if leftGap != rightGap { return leftGap > rightGap }
                if left.loadPerWeek != right.loadPerWeek { return left.loadPerWeek > right.loadPerWeek }
                return left.sortIndex < right.sortIndex
            }
            .prefix(maximumTrades)
            .compactMap { item in
                trade(
                    item,
                    viewerMemberId: viewerMemberId,
                    partnerMemberId: partnerMemberId,
                    partnerName: partnerName,
                    copy: copy
                )
            }
    }

    private static func trade(
        _ item: ChoreItemDTO,
        viewerMemberId: UUID?,
        partnerMemberId: UUID?,
        partnerName: String,
        copy: ChoreCopy
    ) -> ChoreTrade? {
        guard let assignment = item.assignment,
              let owner = assignment.assignedMemberId,
              let viewerVerdict = item.verdict(of: viewerMemberId),
              let partnerVerdict = item.verdict(of: partnerMemberId) else { return nil }
        let viewerSaid = copy.viewerVerdict(viewerVerdict)
        let partnerSaid = copy.partnerVerdict(partnerVerdict, name: partnerName)
        let goesToViewer = owner == viewerMemberId
        return ChoreTrade(
            id: item.id,
            title: item.title,
            line: goesToViewer ? partnerSaid + " " + viewerSaid : viewerSaid + " " + partnerSaid,
            stamp: String(localized: goesToViewer ? "chore.reveal.trade.yours" : "chore.reveal.trade.theirs")
        )
    }

    private static func lists(
        in items: [ChoreItemDTO],
        viewerMemberId: UUID?,
        partnerName: String
    ) -> [ChoreShare] {
        ChoreShareKind.allCases.compactMap { kind in
            let chores = items
                .filter { kind.holds($0, viewerMemberId: viewerMemberId) }
                .map(\.title)
            guard chores.isEmpty == false else { return nil }
            return ChoreShare(id: kind.rawValue, title: kind.title(partnerName: partnerName), chores: chores)
        }
    }
}

enum ChoreShareKind: String, CaseIterable {
    case yours
    case theirs
    case rotating
    case anyone

    func title(partnerName: String) -> String {
        switch self {
        case .yours:
            return String(localized: "chore.reveal.list.yours")
        case .theirs:
            return String.localizedStringWithFormat(String(localized: "chore.reveal.list.theirs"), partnerName)
        case .rotating:
            return String(localized: "chore.reveal.list.rotating")
        case .anyone:
            return String(localized: "chore.reveal.list.anyone")
        }
    }

    func holds(_ item: ChoreItemDTO, viewerMemberId: UUID?) -> Bool {
        guard let assignment = item.assignment else { return false }
        switch self {
        case .yours:
            return assignment.result == .member && assignment.assignedMemberId == viewerMemberId
        case .theirs:
            guard assignment.result == .member, let owner = assignment.assignedMemberId else { return false }
            return owner != viewerMemberId
        case .rotating:
            return assignment.result == .rotate
        case .anyone:
            return assignment.result == .anyone
        }
    }
}
