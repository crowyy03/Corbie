import CorbieCore
import SwiftUI

struct PlanCard: View {
    let plan: PlanDTO

    private var totals: PlanTotals { PlanTotals(plan: plan) }

    var body: some View {
        Card(showsChromeGradient: plan.status == .active) {
            VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                header
                ProgressBar(
                    value: totals.progress,
                    overspend: totals.overspendFraction,
                    accessibilityLabel: String(localized: "plans.card.progress.label"),
                    accessibilityValue: totals.savedOfTarget()
                )
                footer
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: CorbieSpacing.xs) {
            Image(systemName: plan.type.systemImage)
                .foregroundStyle(CorbieColorPalette.text2)
                .accessibilityHidden(true)
            Text(plan.title)
                .corbieBody()
                .fontWeight(.semibold)
                .foregroundStyle(CorbieColorPalette.text)
                .lineLimit(2)
            Spacer(minLength: CorbieSpacing.xs)
            if plan.status == .completed {
                Text(PlansCopy.text(PlanStatus.completed.titleKey))
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
            } else if totals.isOverspent {
                Text(totals.overspendBadge())
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.warn)
            }
        }
    }

    private var footer: some View {
        HStack(alignment: .firstTextBaseline, spacing: CorbieSpacing.xs) {
            Text(totals.savedOfTarget())
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
            Spacer(minLength: CorbieSpacing.xs)
            if let dates = planDateRange(start: plan.startAt, end: plan.endAt) {
                Text(dates)
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    VStack(spacing: CorbieSpacing.m) {
        PlanCard(
            plan: PlanDTO(
                id: UUID(),
                title: "Lisbon in October",
                type: .trip,
                targetAmount: 5000,
                currency: "USD",
                savedAmount: 2400,
                spentAmount: 1900,
                startAt: Date(),
                endAt: Date().addingTimeInterval(14 * 24 * 60 * 60)
            )
        )
        PlanCard(
            plan: PlanDTO(
                id: UUID(),
                title: "Kitchen",
                type: .renovation,
                targetAmount: 4000,
                currency: "USD",
                savedAmount: 4000,
                spentAmount: 4340
            )
        )
    }
    .padding(CorbieSpacing.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CorbieColorPalette.bg)
}
