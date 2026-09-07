import CorbieCore
import SwiftUI

struct MemberColorPicker: View {
    @Binding var selection: MemberColorSlot
    let partnerSlot: MemberColorSlot?
    let partnerName: String

    @Environment(\.palette) private var palette
    @Environment(\.theme) private var theme

    private let swatchSize: CGFloat = 28

    var body: some View {
        HStack(spacing: CorbieSpacing.xs) {
            ForEach(MemberColorSlot.allCases) { slot in
                swatch(slot)
            }
        }
    }

    private func isBlocked(_ slot: MemberColorSlot) -> Bool {
        guard let partnerSlot else { return false }
        return slot.conflicts(with: partnerSlot, in: theme)
    }

    private func label(_ slot: MemberColorSlot) -> String {
        let name = String(localized: String.LocalizationValue(slot.displayNameKey))
        if slot == partnerSlot {
            return String(format: String(localized: "member.color.theirs"), name, partnerName)
        }
        if isBlocked(slot) {
            return String(format: String(localized: "member.color.tooclose"), name, partnerName)
        }
        return name
    }

    private func swatch(_ slot: MemberColorSlot) -> some View {
        let isSelected = selection == slot
        let blocked = isBlocked(slot)
        return Button {
            selection = slot
        } label: {
            Circle()
                .fill(palette.member(slot))
                .frame(width: swatchSize, height: swatchSize)
                .opacity(blocked ? 0.35 : 1)
                .overlay {
                    if slot == partnerSlot {
                        Image(systemName: "checkmark")
                            .font(.system(size: CorbieSpacing.s, weight: .bold))
                            .foregroundStyle(palette.bg)
                    }
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            isSelected ? palette.accent : .clear,
                            lineWidth: CorbieMetrics.hairline * 2
                        )
                        .padding(-CorbieSpacing.xxs)
                }
                .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(blocked)
        .accessibilityLabel(label(slot))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}
