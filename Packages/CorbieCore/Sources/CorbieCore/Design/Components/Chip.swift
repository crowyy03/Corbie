import SwiftUI

public struct Chip: View {
    private let label: String
    private let count: Int?
    private let isSelected: Bool
    private let tint: MemberColorSlot?

    @Environment(\.palette) private var palette

    public init(label: String, count: Int? = nil, isSelected: Bool = false, tint: MemberColorSlot? = nil) {
        self.label = label
        self.count = count
        self.isSelected = isSelected
        self.tint = tint
    }

    private var fill: Color {
        guard isSelected else { return palette.surface }
        guard let tint else { return palette.accent }
        return palette.member(tint)
    }

    private var foreground: Color {
        isSelected ? palette.ctaText : palette.text2
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
                .strokeBorder(isSelected ? .clear : palette.border, lineWidth: CorbieMetrics.hairline)
        )
        .frame(minHeight: CorbieMetrics.minimumTapTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#if DEBUG
#if canImport(UIKit)
#Preview("Chip") {
    PreviewThemes {
        HStack(spacing: CorbieSpacing.xs) {
            Chip(label: "All", count: 12, isSelected: true)
            Chip(label: "Mine", count: 3)
            Chip(label: "Free", isSelected: true, tint: .rose)
        }
    }
}
#endif
#endif
