import CorbieCore
import SwiftUI

struct PaywallView: View {
    @Environment(\.palette) private var palette

    let request: PaywallRequest

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var model = PaywallViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CorbieSpacing.l) {
                    header
                    values
                    offers
                    actions
                    legal
                    links
                }
                .padding(.horizontal, CorbieSpacing.l)
                .padding(.bottom, CorbieSpacing.xxl)
            }
            .background(palette.bg)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("paywall.action.close") { close() }
                }
            }
        }
        .task { await model.load(environment) }
        .sheet(item: $model.openedLink) { link in
            if let url = link.url {
                LegalPageView(url: url)
                    .ignoresSafeArea()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xs) {
            Text(PaywallCopy.reasonText(request.reason))
                .corbieMono()
                .foregroundStyle(palette.text2)
            Text("paywall.headline")
                .corbieScreenTitle()
                .foregroundStyle(palette.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, CorbieSpacing.s)
    }

    private var values: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.s) {
            ForEach(PaywallValueRow.all) { row in
                HStack(alignment: .top, spacing: CorbieSpacing.s) {
                    Image(systemName: row.systemImage)
                        .font(.system(size: CorbieSpacing.l, weight: .light))
                        .foregroundStyle(palette.accent)
                        .frame(width: CorbieSpacing.xl)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                        Text(LocalizedStringKey(row.titleKey))
                            .corbieBody()
                            .fontWeight(.semibold)
                            .foregroundStyle(palette.text)
                        Text(LocalizedStringKey(row.noteKey))
                            .corbieCaption()
                            .foregroundStyle(palette.text2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    @ViewBuilder private var offers: some View {
        switch model.stage {
        case .loading:
            HStack(spacing: CorbieSpacing.s) {
                ProgressView()
                Text("paywall.state.loading")
                    .corbieMono()
                    .foregroundStyle(palette.text2)
            }
            .frame(maxWidth: .infinity, minHeight: CorbieMetrics.controlHeight)
        case .ready:
            VStack(spacing: CorbieSpacing.s) {
                ForEach(model.offers) { offer in
                    offerCard(offer)
                }
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

    private func offerCard(_ offer: SubscriptionOffer) -> some View {
        let isSelected = model.selection == offer.product
        return Button {
            model.select(offer.product)
        } label: {
            HStack(alignment: .center, spacing: CorbieSpacing.s) {
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    HStack(spacing: CorbieSpacing.xs) {
                        Text(LocalizedStringKey(PaywallCopy.titleKey(offer.product)))
                            .corbieBody()
                            .fontWeight(.semibold)
                            .foregroundStyle(palette.text)
                            .fixedSize(horizontal: false, vertical: true)
                        if let badge = PaywallCopy.savingsBadge(for: offer) {
                            Text(badge)
                                .corbieMono()
                                .fontWeight(.semibold)
                                .foregroundStyle(palette.ctaText)
                                .padding(.horizontal, CorbieSpacing.xs)
                                .padding(.vertical, CorbieSpacing.xxs)
                                .background(Capsule(style: .continuous).fill(palette.accent))
                        }
                    }
                    if let permonth = PaywallCopy.monthlyEquivalent(for: offer) {
                        Text(permonth)
                            .corbieMono()
                            .foregroundStyle(palette.text2)
                    }
                }
                Spacer(minLength: CorbieSpacing.xs)
                Text(offer.displayPrice)
                    .corbieBody()
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text)
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? palette.accent : palette.text2)
                    .accessibilityHidden(true)
            }
            .padding(CorbieSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: CorbieMetrics.minimumTapTarget)
            .background(
                RoundedRectangle(cornerRadius: CorbieRadius.card, style: .continuous)
                    .fill(palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CorbieRadius.card, style: .continuous)
                    .strokeBorder(
                        isSelected ? palette.accent : palette.border,
                        lineWidth: isSelected ? 2 : CorbieMetrics.hairline
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var actions: some View {
        VStack(spacing: CorbieSpacing.s) {
            PrimaryButton(title: String(localized: "paywall.action.continue")) {
                Task {
                    if await model.purchase() { close() }
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

            SecondaryButton(title: String(localized: "paywall.action.restore")) {
                Task {
                    if await model.restore() { close() }
                }
            }
            .disabled(model.isWorking)
        }
    }

    private var legal: some View {
        Text(legalText)
            .corbieMono()
            .foregroundStyle(palette.text2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var links: some View {
        HStack(spacing: CorbieSpacing.m) {
            ForEach(LegalPage.allCases) { link in
                Button {
                    model.open(link)
                } label: {
                    Text(LocalizedStringKey(link.paywallTitleKey))
                        .corbieCaption()
                        .foregroundStyle(palette.text)
                        .underline()
                        .frame(minHeight: CorbieMetrics.minimumTapTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private var legalText: String {
        guard let offer = model.selectedOffer else { return PaywallCopy.text("paywall.legal.generic") }
        return PaywallCopy.legalText(for: offer)
    }

    private func close() {
        environment.premiumGate.dismissPaywall()
        dismiss()
    }
}

#if DEBUG
#Preview("Trial ended") {
    PaywallView(request: PaywallRequest(reason: .trialEnded))
        .environment(AppEnvironment.previewSignedIn())
}

#Preview("Capsules") {
    PaywallView(request: PaywallRequest(reason: .capsules, action: .capsules))
        .environment(AppEnvironment.previewSignedIn())
}
#endif
