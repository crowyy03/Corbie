import CorbieCore
import SwiftUI

struct PaywallCheckout: View {
    @Environment(\.palette) private var palette
    @Environment(AppEnvironment.self) private var environment

    @Bindable var model: PaywallViewModel
    let onPurchase: () -> Void

    var body: some View {
        VStack(spacing: CorbieSpacing.s) {
            plans
            PrimaryButton(title: PaywallCopy.callToAction(for: model.selectedOffer)) {
                Task {
                    if await model.purchase() { onPurchase() }
                }
            }
            .disabled(model.canContinue == false)
            if let message = model.message {
                Text(message)
                    .corbieCaption()
                    .foregroundStyle(palette.warn)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            legal
            links
        }
        .sheet(item: $model.openedLink) { link in
            if let url = link.url {
                LegalPageView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    @ViewBuilder private var plans: some View {
        switch model.stage {
        case .loading:
            HStack(spacing: CorbieSpacing.s) {
                ProgressView()
                Text("paywall.state.loading")
                    .corbieCaption()
                    .foregroundStyle(palette.text2)
            }
            .frame(maxWidth: .infinity, minHeight: CorbieMetrics.controlHeight)
        case .ready:
            PlanSelector(offers: model.offers, selection: model.selection) { product in
                model.select(product)
            }
        case .unavailable:
            Card {
                VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                    Text("paywall.state.unavailable")
                        .corbieBody()
                        .foregroundStyle(palette.text)
                    SecondaryButton(title: String(localized: "paywall.action.retry")) {
                        Task { await model.reload(environment) }
                    }
                }
            }
        }
    }

    private var legal: some View {
        Text(model.selectedOffer.map(PaywallCopy.legalText) ?? PaywallCopy.text("paywall.legal.generic"))
            .corbieCaption()
            .foregroundStyle(palette.text2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var links: some View {
        HStack(spacing: CorbieSpacing.m) {
            linkButton(title: String(localized: "paywall.action.restore")) {
                Task {
                    if await model.restore() { onPurchase() }
                }
            }
            .disabled(model.isWorking)
            ForEach(LegalPage.allCases) { page in
                linkButton(title: PaywallCopy.text(page.paywallTitleKey)) {
                    model.openedLink = page
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func linkButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .corbieCaption()
                .foregroundStyle(palette.text)
                .underline()
                .frame(minHeight: CorbieMetrics.minimumTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
    }
}
