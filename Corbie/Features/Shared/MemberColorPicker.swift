import CorbieCore
import SwiftUI

struct MemberColorPicker: View {
    @Binding var selection: MemberColorKey

    private let swatchSize: CGFloat = 28

    var body: some View {
        HStack(spacing: CorbieSpacing.xs) {
            ForEach(CorbieColorPalette.partnerPalette) { key in
                swatch(key)
            }
        }
    }

    private func swatch(_ key: MemberColorKey) -> some View {
        let isSelected = selection == key
        return Button {
            selection = key
        } label: {
            Circle()
                .fill(key.color)
                .frame(width: swatchSize, height: swatchSize)
                .overlay {
                    Circle()
                        .strokeBorder(
                            isSelected ? CorbieColorPalette.ice : .clear,
                            lineWidth: CorbieMetrics.hairline * 2
                        )
                        .padding(-CorbieSpacing.xxs)
                }
                .frame(width: CorbieMetrics.minimumTapTarget, height: CorbieMetrics.minimumTapTarget)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(MemberColorPicker.name(key))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    static func name(_ key: MemberColorKey) -> String {
        switch key {
        case .p1: return String(localized: "onboarding.profile.color.p1")
        case .p2: return String(localized: "onboarding.profile.color.p2")
        case .p3: return String(localized: "onboarding.profile.color.p3")
        case .p4: return String(localized: "onboarding.profile.color.p4")
        case .p5: return String(localized: "onboarding.profile.color.p5")
        case .p6: return String(localized: "onboarding.profile.color.p6")
        }
    }
}
