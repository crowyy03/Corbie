import CorbieCore
import Foundation

struct ProfileDraft: Equatable {
    var displayName = ""
    var colorKey: MemberColorKey = .defaultA
    var togetherSince: Date?
    var birthdayMonth: Int?
    var birthdayDay: Int?

    var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isComplete: Bool { trimmedName.isEmpty == false }

    var hasBirthday: Bool { birthdayMonth != nil && birthdayDay != nil }

    var memberDraft: MemberDraft {
        MemberDraft(
            displayName: trimmedName.isEmpty ? nil : trimmedName,
            colorKey: colorKey.rawValue,
            birthdayMonth: birthdayMonth,
            birthdayDay: birthdayDay
        )
    }

    func applied(to member: MemberDTO) -> MemberDTO {
        var updated = member
        updated.displayName = trimmedName.isEmpty ? nil : trimmedName
        updated.colorKey = colorKey.rawValue
        updated.birthdayMonth = birthdayMonth
        updated.birthdayDay = birthdayDay
        return updated
    }

    func applied(to space: SpaceDTO) -> SpaceDTO {
        var updated = space
        updated.togetherSince = togetherSince
        return updated
    }

    mutating func setBirthday(enabled: Bool, calendar: Calendar = .current) {
        guard enabled else {
            birthdayMonth = nil
            birthdayDay = nil
            return
        }
        let today = calendar.dateComponents([.month, .day], from: Date())
        birthdayMonth = birthdayMonth ?? today.month ?? 1
        birthdayDay = birthdayDay ?? today.day ?? 1
        clampBirthdayDay()
    }

    mutating func clampBirthdayDay() {
        guard let month = birthdayMonth, let day = birthdayDay else { return }
        birthdayDay = PersonBirthday.clampDay(day, month: month)
    }

    static func from(member: MemberDTO?, space: SpaceDTO?, appleName: String?) -> ProfileDraft {
        var draft = ProfileDraft()
        draft.displayName = member?.displayName ?? appleName ?? ""
        draft.colorKey = MemberColor(key: member?.colorKey).key
        draft.togetherSince = space?.togetherSince
        draft.birthdayMonth = member?.birthdayMonth
        draft.birthdayDay = member?.birthdayDay
        return draft
    }
}
