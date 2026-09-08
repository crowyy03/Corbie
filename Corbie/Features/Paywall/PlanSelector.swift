import CorbieCore
import SwiftUI

struct PlanSelector: View {
    @Environment(\.palette) private var palette

    let offers: [SubscriptionOffer]
    let selection: CorbieProduct?
    let select: (CorbieProduct) -> Void

    private var monthly: SubscriptionOffer? {
        offers.first { $0.product == .monthly }
    }

    var body: some View {
        VStack(spacing: CorbieSpacing.xs) {
            ForEach(offers) { offer in
                card(offer)
            }
        }
    }

    @ViewBuilder private func card(_ offer: SubscriptionOffer) -> some View {
        let isSelected = selection == offer.product
        let isLeading = offer.product == .yearly
        Button {
            select(offer.product)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: CorbieSpacing.s) {
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    HStack(spacing: CorbieSpacing.xs) {
                        Text(LocalizedStringKey(PaywallCopy.titleKey(offer.product)))
                            .corbieBody()
                            .fontWeight(isLeading ? .semibold : .regular)
                            .foregroundStyle(palette.text)
                        if let badge = PaywallCopy.savingsBadge(for: offer) {
                            Text(badge)
                                .corbieCaption()
                                .fontWeight(.semibold)
                                .foregroundStyle(palette.ctaText)
                                .padding(.horizontal, CorbieSpacing.xs)
                                .padding(.vertical, CorbieSpacing.xxs)
                                .background(Capsule(style: .continuous).fill(palette.accent))
                        }
                    }
                    if isLeading, let perMonth = PaywallCopy.monthlyEquivalent(for: offer) {
                        Text(perMonth)
                            .corbieCaption()
                            .foregroundStyle(palette.text2)
                    }
                }
                Spacer(minLength: CorbieSpacing.xxs)
                if let payingMonthly = PaywallCopy.yearAtMonthlyPrice(for: offer, monthly: monthly) {
                    Text(payingMonthly)
                        .corbieCaption()
                        .foregroundStyle(palette.text2)
                        .strikethrough()
                        .accessibilityLabel(
                            Text(String(format: PaywallCopy.text("paywall.offer.insteadof"), payingMonthly))
                        )
                }
                Text(offer.displayPrice)
                    .corbieBody()
                    .fontWeight(.semibold)
                    .foregroundStyle(palette.text)
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? palette.accent : palette.text2)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, CorbieSpacing.m)
            .padding(.vertical, isLeading ? CorbieSpacing.s : CorbieSpacing.xs)
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
}

#if DEBUG
#Preview("PlanSelector") {
    let style = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))
    let offers = SubscriptionOfferMath.sorted(
        SubscriptionOfferMath.applySavings(to: [
            SubscriptionOffer(
                product: .monthly,
                displayPrice: "$4.99",
                price: Decimal(string: "4.99") ?? 0,
                priceFormatStyle: style
            ),
            SubscriptionOffer(
                product: .yearly,
                displayPrice: "$29.99",
                price: Decimal(string: "29.99") ?? 0,
                priceFormatStyle: style,
                eligibleFreeTrialDays: 14
            )
        ])
    )
    return PlanSelector(offers: offers, selection: .yearly) { _ in }
        .padding(CorbieSpacing.l)
        .corbieTheme(.ice)
}
#endif
