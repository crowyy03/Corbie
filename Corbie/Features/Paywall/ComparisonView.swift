import CorbieCore
import SwiftUI

struct ComparisonView: View {
    @Environment(\.palette) private var palette
    @Environment(AppEnvironment.self) private var environment

    let request: PaywallRequest
    let onClose: () -> Void

    @State private var model = PaywallViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                header
                table
                PaywallCheckout(model: model, onPurchase: onClose)
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.bottom, CorbieSpacing.l)
        }
        .background(palette.bg)
        .safeAreaInset(edge: .top, spacing: 0) { closeRow }
        .task { await model.load(environment) }
    }

    private var closeRow: some View {
        HStack {
            Spacer(minLength: 0)
            Button("paywall.action.close") { onClose() }
                .corbieBody()
                .foregroundStyle(palette.text)
                .frame(minWidth: CorbieMetrics.minimumTapTarget, minHeight: CorbieMetrics.minimumTapTarget)
        }
        .padding(.horizontal, CorbieSpacing.m)
        .background(palette.bg)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            Text(LocalizedStringKey(PaywallCopy.headerKey(request.reason)))
                .corbieBody()
                .fontWeight(.semibold)
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
            Text(PaywallCopy.reasonText(request.reason))
                .corbieCaption()
                .foregroundStyle(palette.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var table: some View {
        VStack(spacing: CorbieSpacing.xxs) {
            HStack(alignment: .top, spacing: CorbieSpacing.s) {
                Text("paywall.compare.free")
                    .corbieSectionCaps()
                    .foregroundStyle(palette.text2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("paywall.compare.premium")
                    .corbieSectionCaps()
                    .foregroundStyle(palette.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(ComparisonRow.all) { row in
                HStack(alignment: .top, spacing: CorbieSpacing.s) {
                    cell(row.freeKey, color: palette.text2)
                    cell(row.premiumKey, color: palette.text)
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(CorbieSpacing.s)
        .background(
            RoundedRectangle(cornerRadius: CorbieRadius.card, style: .continuous)
                .fill(palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CorbieRadius.card, style: .continuous)
                .strokeBorder(palette.border, lineWidth: CorbieMetrics.hairline)
        )
    }

    @ViewBuilder private func cell(_ key: String?, color: Color) -> some View {
        if let key {
            Text(LocalizedStringKey(key))
                .corbieCaption()
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: 0)
        }
    }
}

#if DEBUG
#Preview("After the trial") {
    ComparisonView(request: PaywallRequest(reason: .trialEnded)) {}
        .environment(AppEnvironment.previewSignedIn())
}

#Preview("Capsules") {
    ComparisonView(request: PaywallRequest(reason: .capsules, action: .capsules)) {}
        .environment(AppEnvironment.previewSignedIn())
}
#endif
