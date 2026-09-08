import SwiftUI

public struct ThemePreviewCard: View {
    private let theme: CorbieTheme
    private let name: String
    private let isSelected: Bool
    private let action: () -> Void

    @Environment(\.palette) private var palette

    public init(theme: CorbieTheme, name: String, isSelected: Bool, action: @escaping () -> Void) {
        self.theme = theme
        self.name = name
        self.isSelected = isSelected
        self.action = action
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: CorbieRadius.field, style: .continuous)
    }

    public var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
                miniature
                Text(name)
                    .corbieCaption()
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? palette.text : palette.text2)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(name))
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var miniature: some View {
        let preview = theme.palette
        return VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            RoundedRectangle(cornerRadius: CorbieSpacing.xxs, style: .continuous)
                .fill(preview.surface)
                .frame(height: CorbieSpacing.l)
                .overlay(alignment: .leading) {
                    HStack(spacing: CorbieSpacing.xxs) {
                        Circle().fill(preview.member(.teal)).frame(width: CorbieSpacing.xs, height: CorbieSpacing.xs)
                        Circle().fill(preview.member(.rose)).frame(width: CorbieSpacing.xs, height: CorbieSpacing.xs)
                    }
                    .padding(.leading, CorbieSpacing.xs)
                }
            Capsule(style: .continuous)
                .fill(preview.accent)
                .frame(width: CorbieSpacing.xxl, height: CorbieSpacing.xxs)
        }
        .padding(CorbieSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shape.fill(preview.bg))
        .overlay(
            shape.strokeBorder(
                isSelected ? palette.accent : palette.border,
                lineWidth: isSelected ? CorbieMetrics.hairline * 2 : CorbieMetrics.hairline
            )
        )
    }
}

#if DEBUG
#if canImport(UIKit)
#Preview("ThemePreviewCard") {
    PreviewThemes {
        HStack(spacing: CorbieSpacing.s) {
            ForEach(CorbieTheme.allCases) { theme in
                ThemePreviewCard(theme: theme, name: theme.rawValue.capitalized, isSelected: theme == .sand) {}
            }
        }
    }
}
#endif
#endif
