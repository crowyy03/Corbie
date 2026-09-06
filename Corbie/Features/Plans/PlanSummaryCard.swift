import CorbieCore
import SwiftUI

struct PlanSummaryCard: View {
    let plan: PlanDTO
    let totals: PlanTotals

    var body: some View {
        Card(showsChromeGradient: true) {
            VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                header
                ProgressBar(
                    value: totals.progress,
                    overspend: totals.overspendFraction,
                    accessibilityLabel: String(localized: "plans.card.progress.label"),
                    accessibilityValue: totals.savedOfTarget()
                )
                amounts
                if totals.isOverspent {
                    Text(overspendText)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.warn)
                }
                if let dates = planDateRange(start: plan.startAt, end: plan.endAt) {
                    Text(dates)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: CorbieSpacing.xs) {
            Image(systemName: plan.type.systemImage)
                .foregroundStyle(CorbieColorPalette.text2)
                .accessibilityHidden(true)
            Text(PlansCopy.text(plan.type.titleKey))
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
            Spacer(minLength: CorbieSpacing.xs)
            if plan.status != .active {
                Text(PlansCopy.text(plan.status.titleKey))
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
            }
        }
    }

    private var amounts: some View {
        HStack(alignment: .top, spacing: CorbieSpacing.s) {
            column(label: String(localized: "plans.detail.saved"), amount: totals.saved)
            column(label: String(localized: "plans.detail.added"), amount: totals.added)
            column(label: String(localized: "plans.detail.left"), amount: totals.left)
        }
    }

    private func column(label: String, amount: Double) -> some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            SectionCaps(text: label)
            Text(totals.money(amount).formatted())
                .corbieBody()
                .fontWeight(.semibold)
                .foregroundStyle(CorbieColorPalette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var overspendText: String {
        String(
            format: PlansCopy.text("plans.detail.overspend"),
            totals.money(totals.overspend).formatted()
        )
    }
}

#if DEBUG
#Preview {
    let plan = PlanDTO(
        id: UUID(),
        title: "Kitchen",
        type: .renovation,
        targetAmount: 4000,
        currency: "USD",
        savedAmount: 3200,
        addedAmount: 4340,
        startAt: Date(),
        endAt: Date().addingTimeInterval(30 * 24 * 60 * 60)
    )
    return PlanSummaryCard(plan: plan, totals: PlanTotals(plan: plan))
        .padding(CorbieSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CorbieColorPalette.bg)
}
#endif
