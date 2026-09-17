import CorbieCore
import Foundation

enum PartnerChangeRule {
    static func needsReload(stored: MemberDTO?, session: MemberDTO?) -> Bool {
        ShownPartner(stored) != ShownPartner(session)
    }
}

private struct ShownPartner: Equatable {
    let id: UUID
    let displayName: String?
    let colorKey: String?
    let birthdayMonth: Int?
    let birthdayDay: Int?
    let joinedAt: Date?
    let sharesBusyTimes: Bool

    init?(_ member: MemberDTO?) {
        guard let member else { return nil }
        id = member.id
        displayName = member.displayName
        colorKey = member.colorKey
        birthdayMonth = member.birthdayMonth
        birthdayDay = member.birthdayDay
        joinedAt = member.joinedAt
        sharesBusyTimes = member.sharesBusyTimes
    }
}
