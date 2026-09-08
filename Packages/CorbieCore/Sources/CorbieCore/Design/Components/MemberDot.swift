import SwiftUI

public struct MemberDot: View {
    private let slot: MemberColorSlot?
    private let size: CGFloat
    private let accessibilityLabel: String?

    @Environment(\.palette) private var palette

    public init(slot: MemberColorSlot?, size: CGFloat = CorbieMetrics.memberDotSize, accessibilityLabel: String? = nil) {
        self.slot = slot
        self.size = size
        self.accessibilityLabel = accessibilityLabel
    }

    private var fill: Color {
        guard let slot else { return palette.text2 }
        return palette.member(slot)
    }

    public var body: some View {
        Circle()
            .fill(fill)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(palette.bg.opacity(0.5), lineWidth: CorbieMetrics.hairline))
            .accessibilityHidden(accessibilityLabel == nil)
            .accessibilityLabel(Text(accessibilityLabel ?? ""))
    }
}

#if DEBUG
#if canImport(UIKit)
#Preview("MemberDot") {
    PreviewThemes {
        HStack(spacing: CorbieSpacing.s) {
            ForEach(MemberColorSlot.allCases) { slot in
                MemberDot(slot: slot, size: CorbieSpacing.l)
            }
            MemberDot(slot: nil, size: CorbieSpacing.l)
        }
    }
}
#endif
#endif
