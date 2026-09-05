import SwiftUI

public struct Chip: View {
    private let label: String
    private let count: Int?
    private let isSelected: Bool
    private let tint: Color?

    public init(label: String, count: Int? = nil, isSelected: Bool = false, tint: Color? = nil) {
        self.label = label
        self.count = count
        self.isSelected = isSelected
        self.tint = tint
    }

    private var fill: Color {
        isSelected ? (tint ?? CorbieColorPalette.ice) : CorbieColorPalette.surface
    }

    private var foreground: Color {
        isSelected ? CorbieColorPalette.accentInk : CorbieColorPalette.text2
    }

    public var body: some View {
        HStack(spacing: CorbieSpacing.xs) {
            Text(label)
                .corbieCaption()
                .fontWeight(.semibold)
            if let count {
                Text(count.formatted())
                    .corbieMono()
                    .foregroundStyle(foreground.opacity(0.7))
            }
        }
        .foregroundStyle(foreground)
        .lineLimit(1)
        .padding(.horizontal, CorbieSpacing.s)
        .frame(minHeight: CorbieMetrics.chipHeight)
        .background(Capsule(style: .continuous).fill(fill))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(isSelected ? .clear : CorbieColorPalette.border, lineWidth: CorbieMetrics.hairline)
        )
        .frame(minHeight: CorbieMetrics.minimumTapTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
struct ChipGallery: View {
    var body: some View {
        HStack(spacing: CorbieSpacing.xs) {
            Chip(label: "All", count: 12, isSelected: true)
            Chip(label: "Mine", count: 3)
            Chip(label: "Free", tint: MemberColorKey.p3.color)
        }
        .padding(CorbieSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CorbieColorPalette.bg)
    }
}

#if canImport(UIKit)
#Preview("Chip light") {
    ChipGallery().preferredColorScheme(.light)
}

#Preview("Chip dark") {
    ChipGallery().preferredColorScheme(.dark)
}
#endif
#endif
