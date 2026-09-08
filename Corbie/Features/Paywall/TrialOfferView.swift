import CorbieCore
import SwiftUI

struct PaywallFlow: View {
    @Environment(AppEnvironment.self) private var environment

    let onClose: () -> Void

    @State private var screen: PaywallScreen = .trialOffer

    var body: some View {
        switch screen {
        case .trialOffer:
            TrialOfferView(onCompare: openComparison, onClose: onClose)
        case .comparison:
            ComparisonView(request: PaywallRequest(reason: .settings), onClose: onClose)
        }
    }

    private func openComparison() {
        environment.analytics.record(.comparisonShown(reason: .settings))
        screen = .comparison
    }
}

struct TrialOfferView: View {
    @Environment(\.palette) private var palette
    @Environment(AppEnvironment.self) private var environment

    let onCompare: () -> Void
    let onClose: () -> Void

    @State private var model = PaywallViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                header
                values
                PaywallCheckout(model: model, onPurchase: onClose)
                skip
            }
            .padding(.horizontal, CorbieSpacing.l)
            .padding(.top, CorbieSpacing.xl)
            .padding(.bottom, CorbieSpacing.xl)
        }
        .background(palette.bg)
        .task {
            await model.load(environment)
            environment.analytics.record(.trialOfferShown)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            Text("paywall.headline")
                .corbieScreenTitle()
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
            Text("paywall.trial.sub")
                .corbieBody()
                .foregroundStyle(palette.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var values: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.s) {
            ForEach(PaywallValueRow.all) { row in
                HStack(alignment: .firstTextBaseline, spacing: CorbieSpacing.s) {
                    Image(systemName: row.systemImage)
                        .font(.system(size: CorbieFont.bodySize, weight: .light))
                        .foregroundStyle(palette.accent)
                        .frame(width: CorbieSpacing.xl, alignment: .leading)
                        .accessibilityHidden(true)
                    Text(LocalizedStringKey(row.textKey))
                        .corbieBody()
                        .foregroundStyle(palette.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var skip: some View {
        Button(action: onCompare) {
            Text("paywall.trial.skip")
                .corbieCaption()
                .foregroundStyle(palette.text2)
                .frame(maxWidth: .infinity, minHeight: CorbieMetrics.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Trial offer") {
    PaywallFlow {}
        .environment(AppEnvironment.previewSignedIn())
}
#endif
