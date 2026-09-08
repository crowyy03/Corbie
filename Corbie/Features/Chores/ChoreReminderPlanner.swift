import CorbieCore
import Foundation

struct ChoreReminderPlan: Equatable {
    let setId: UUID
    let partnerName: String
}

enum ChoreReminderPlanner {
    static let toldKey = "corbie.chore.split.told"

    static func plan(
        sets: [ChoreSetDTO],
        viewerMemberId: UUID?,
        partnerMemberId: UUID?,
        partnerName: String,
        alreadyToldAbout: String?
    ) -> ChoreReminderPlan? {
        guard let newest = sets.first, newest.status == .rating else { return nil }
        guard newest.hasRatedEverything(partnerMemberId),
              newest.hasRatedEverything(viewerMemberId) == false else { return nil }
        guard alreadyToldAbout != newest.id.uuidString else { return nil }
        return ChoreReminderPlan(setId: newest.id, partnerName: partnerName)
    }
}
