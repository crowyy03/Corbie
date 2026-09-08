import CorbieCore
import Foundation

struct ChoresContext: Equatable {
    var spaceId: UUID?
    var memberId: UUID?
    var partnerId: UUID?
    var partnerName: String
    var prefs: NotificationPrefs

    init(
        spaceId: UUID? = nil,
        memberId: UUID? = nil,
        partnerId: UUID? = nil,
        partnerName: String = "",
        prefs: NotificationPrefs = .allEnabled
    ) {
        self.spaceId = spaceId
        self.memberId = memberId
        self.partnerId = partnerId
        self.partnerName = partnerName
        self.prefs = prefs
    }
}

enum ChoreSplitState: Equatable {
    case notStarted
    case building
    case yourTurnToRate
    case waitingForPartner
    case readyToReveal
    case revealed
    case applied(Date)
    case needsResplit(Date)

    static func make(
        sets: [ChoreSetDTO],
        viewerMemberId: UUID?,
        partnerMemberId: UUID?,
        now: Date
    ) -> ChoreSplitState {
        guard let newest = sets.first else { return .notStarted }
        switch newest.status {
        case .building:
            return .building
        case .rating:
            let viewerIsDone = newest.hasRatedEverything(viewerMemberId)
            let partnerIsDone = newest.hasRatedEverything(partnerMemberId)
            if viewerIsDone, partnerIsDone { return .readyToReveal }
            return viewerIsDone ? .waitingForPartner : .yourTurnToRate
        case .revealed:
            return .revealed
        case .applied:
            guard let appliedAt = newest.appliedAt else { return .notStarted }
            return newest.needsResplit(at: now) ? .needsResplit(appliedAt) : .applied(appliedAt)
        }
    }

    var waitsForViewer: Bool {
        self == .yourTurnToRate || self == .readyToReveal
    }
}
