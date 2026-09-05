import SwiftUI

public struct TrialBanner: View {
    private let daysLeft: Int
    private let message: String
    private let actionTitle: String
    private let action: () -> Void

    public init(daysLeft: Int, message: String, actionTitle: String, action: @escaping () -> Void) {
        self.daysLeft = daysLeft
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(spacing: CorbieSpacing.s) {
            Text(daysLeft.formatted())
                .corbieMono()
                .fontWeight(.bold)
                .foregroundStyle(CorbieColorPalette.accentInk)
                .padding(.horizontal, CorbieSpacing.xs)
                .frame(minHeight: CorbieSpacing.xl)
                .background(Capsule(style: .continuous).fill(CorbieColorPalette.ice))
                .accessibilityHidden(true)

            Text(message)
                .corbieCaption()
                .foregroundStyle(CorbieColorPalette.text)
                .lineLimit(2)

            Spacer(minLength: CorbieSpacing.xs)

            Button(action: action) {
                Text(actionTitle)
                    .corbieCaption()
                    .fontWeight(.semibold)
                    .foregroundStyle(CorbieColorPalette.text)
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
                .fill(CorbieColorPalette.elevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CorbieRadius.card, style: .continuous)
                .strokeBorder(CorbieColorPalette.border, lineWidth: CorbieMetrics.hairline)
        )
    }
}

#if DEBUG
struct TrialBannerGallery: View {
    var body: some View {
        TrialBanner(daysLeft: 2, message: "Trial ends in 2 days", actionTitle: "See plans") {}
            .padding(CorbieSpacing.l)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CorbieColorPalette.bg)
    }
}

#if canImport(UIKit)
#Preview("TrialBanner light") {
    TrialBannerGallery().preferredColorScheme(.light)
}

#Preview("TrialBanner dark") {
    TrialBannerGallery().preferredColorScheme(.dark)
}
#endif
#endif
