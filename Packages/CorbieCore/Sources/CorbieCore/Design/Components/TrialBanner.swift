import SwiftUI

public struct TrialBanner: View {
    private let daysLeft: Int?
    private let message: String
    private let actionTitle: String
    private let action: () -> Void

    @Environment(\.palette) private var palette

    public init(daysLeft: Int?, message: String, actionTitle: String, action: @escaping () -> Void) {
        self.daysLeft = daysLeft
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(spacing: CorbieSpacing.s) {
            if let daysLeft {
                Text(daysLeft.formatted())
                    .corbieMono()
                    .fontWeight(.bold)
                    .foregroundStyle(palette.ctaText)
                    .padding(.horizontal, CorbieSpacing.xs)
                    .frame(minHeight: CorbieSpacing.xl)
                    .background(Capsule(style: .continuous).fill(palette.accent))
                    .accessibilityHidden(true)
            }

            Text(message)
                .corbieCaption()
                .foregroundStyle(palette.text)
                .lineLimit(2)

            Spacer(minLength: CorbieSpacing.xs)

            Button(action: action) {
                Text(actionTitle)
                    .corbieCaption()
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text)
                    .padding(.horizontal, CorbieSpacing.s)
                    .frame(minHeight: CorbieMetrics.minimumTapTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(actionTitle))
        }
        .padding(.horizontal, CorbieSpacing.m)
        .padding(.vertical, CorbieSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: CorbieRadius.card, style: .continuous)
                .fill(palette.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CorbieRadius.card, style: .continuous)
                .strokeBorder(palette.border, lineWidth: CorbieMetrics.hairline)
        )
    }
}

#if DEBUG
#if canImport(UIKit)
#Preview("TrialBanner") {
    PreviewThemes {
        TrialBanner(daysLeft: 2, message: "Trial ends in 2 days", actionTitle: "See plans") {}
    }
}
#endif
#endif
