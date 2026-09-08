import SwiftUI

public struct UsPill: View {
    private let slotA: MemberColorSlot?
    private let slotB: MemberColorSlot?
    private let badge: Bool
    private let accessibilityLabel: String?

    @Environment(\.palette) private var palette

    private let circleSize = CorbieMetrics.usPillCircleSize

    public init(
        slotA: MemberColorSlot?,
        slotB: MemberColorSlot?,
        badge: Bool = false,
        accessibilityLabel: String? = nil
    ) {
        self.slotA = slotA
        self.slotB = slotB
        self.badge = badge
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: -circleSize / 3) {
            circle(slotA)
            circle(slotB)
        }
        .padding(.horizontal, CorbieSpacing.xs)
        .frame(minWidth: CorbieMetrics.minimumTapTarget, minHeight: CorbieMetrics.minimumTapTarget)
        .overlay(alignment: .topTrailing) {
            if badge {
                Circle()
                    .fill(palette.accent)
                    .frame(width: CorbieSpacing.xs, height: CorbieSpacing.xs)
                    .overlay(Circle().strokeBorder(palette.bg, lineWidth: 2))
                    .padding(CorbieSpacing.xxs)
            }
        }
        .contentShape(Capsule(style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(accessibilityLabel == nil)
        .accessibilityLabel(Text(accessibilityLabel ?? ""))
    }

    private func circle(_ slot: MemberColorSlot?) -> some View {
        Circle()
            .fill(slot.map(palette.member) ?? palette.text2)
            .frame(width: circleSize, height: circleSize)
            .overlay(Circle().strokeBorder(palette.bg, lineWidth: 2))
    }
}

#if DEBUG
#if canImport(UIKit)
#Preview("UsPill") {
    PreviewThemes {
        HStack(spacing: CorbieSpacing.m) {
            UsPill(slotA: .teal, slotB: .rose, accessibilityLabel: "Both of you")
            UsPill(slotA: .teal, slotB: .rose, badge: true, accessibilityLabel: "Both of you")
        }
    }
}
#endif
#endif
