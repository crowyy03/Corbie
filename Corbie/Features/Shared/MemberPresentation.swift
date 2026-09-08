import CorbieCore
import SwiftUI

extension AppEnvironment {
    func member(id: UUID?) -> MemberDTO? {
        guard let id else { return nil }
        if currentMember?.id == id { return currentMember }
        if partner?.id == id { return partner }
        return nil
    }

    func isCurrentMember(_ id: UUID?) -> Bool {
        guard let id, let currentMember else { return false }
        return currentMember.id == id
    }

    func memberSlot(id: UUID?) -> MemberColorSlot? {
        member(id: id)?.colorSlot
    }

    func memberName(id: UUID?) -> String {
        guard let member = member(id: id) else { return String(localized: "member.name.unknown") }
        if isCurrentMember(member.id) { return String(localized: "member.name.you") }
        return member.displayName ?? String(localized: "member.name.partner")
    }

    var partnerName: String {
        partner?.displayName ?? String(localized: "member.name.partner")
    }

    func showColorShift(_ saved: MemberSaveResult) {
        guard let shifted = saved.shiftedColorFrom else { return }
        toasts.show(
            message: String(
                format: String(localized: "settings.you.color.shifted"),
                String(localized: String.LocalizationValue(shifted.displayNameKey)),
                String(localized: String.LocalizationValue(saved.member.colorSlot.displayNameKey))
            )
        )
    }
}
