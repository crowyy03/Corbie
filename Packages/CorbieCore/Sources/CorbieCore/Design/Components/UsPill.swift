import SwiftUI

public struct UsPill: View {
    private let colorA: Color
    private let colorB: Color
    private let accessibilityLabel: String?

    private let circleSize = CorbieMetrics.usPillCircleSize

    public init(colorA: Color, colorB: Color, accessibilityLabel: String? = nil) {
        self.colorA = colorA
        self.colorB = colorB
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        HStack(spacing: -circleSize / 3) {
            circle(colorA)
            circle(colorB)
        }
        .padding(.horizontal, CorbieSpacing.xs)
        .frame(minWidth: CorbieMetrics.minimumTapTarget, minHeight: CorbieMetrics.minimumTapTarget)
        .contentShape(Capsule(style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityHidden(accessibilityLabel == nil)
        .accessibilityLabel(Text(accessibilityLabel ?? ""))
    }

    private func circle(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: circleSize, height: circleSize)
            .overlay(Circle().strokeBorder(CorbieColorPalette.bg, lineWidth: 2))
    }
}

#if DEBUG
struct UsPillGallery: View {
    var body: some View {
        UsPill(
            colorA: MemberColorKey.defaultA.color,
            colorB: MemberColorKey.defaultB.color,
            accessibilityLabel: "Both of you"
        )
        .padding(CorbieSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CorbieColorPalette.bg)
    }
}

#if canImport(UIKit)
#Preview("UsPill light") {
    UsPillGallery().preferredColorScheme(.light)
}

#Preview("UsPill dark") {
    UsPillGallery().preferredColorScheme(.dark)
}
#endif
#endif
