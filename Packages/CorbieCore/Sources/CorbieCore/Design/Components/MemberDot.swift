import SwiftUI

public struct MemberDot: View {
    private let color: Color
    private let size: CGFloat
    private let accessibilityLabel: String?

    public init(color: Color, size: CGFloat = CorbieMetrics.memberDotSize, accessibilityLabel: String? = nil) {
        self.color = color
        self.size = size
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(CorbieColorPalette.bg.opacity(0.5), lineWidth: CorbieMetrics.hairline))
            .accessibilityHidden(accessibilityLabel == nil)
            .accessibilityLabel(Text(accessibilityLabel ?? ""))
    }
}

#if DEBUG
struct MemberDotGallery: View {
    var body: some View {
        HStack(spacing: CorbieSpacing.s) {
            ForEach(CorbieColorPalette.partnerPalette) { key in
                MemberDot(color: key.color, size: CorbieSpacing.l)
            }
        }
        .padding(CorbieSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CorbieColorPalette.bg)
    }
}

#if canImport(UIKit)
#Preview("MemberDot light") {
    MemberDotGallery().preferredColorScheme(.light)
}

#Preview("MemberDot dark") {
    MemberDotGallery().preferredColorScheme(.dark)
}
#endif
#endif
