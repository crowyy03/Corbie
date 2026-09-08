import CorbieCore
import SwiftUI

struct PlanSummaryCard: View {
    @Environment(\.palette) private var palette

    let plan: PlanDTO
    let totals: PlanTotals

    var body: some View {
        Card(isHighlighted: true) {
            VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                header
                if plan.isOpenEnded {
                    total
                } else {
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
                            .foregroundStyle(palette.warn)
                    }
                }
                if let dates = planDateRange(start: plan.startAt, end: plan.endAt) {
                    Text(dates)
                        .corbieMono()
                        .foregroundStyle(palette.text2)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: CorbieSpacing.xs) {
            Image(systemName: plan.type.systemImage)
                .foregroundStyle(palette.text2)
                .accessibilityHidden(true)
            Text(PlansCopy.text(plan.type.titleKey))
                .corbieMono()
                .foregroundStyle(palette.text2)
            Spacer(minLength: CorbieSpacing.xs)
            if plan.status != .active {
                Text(PlansCopy.text(plan.status.titleKey))
                    .corbieMono()
                    .foregroundStyle(palette.text2)
            }
        }
    }

    private var total: some View {
        VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
            Text(totals.money(totals.saved).formatted())
                .corbieCounter()
                .foregroundStyle(palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            Text(planOpenSubtitle(startedAt: plan.createdAt, contributionCount: plan.expenseCount))
                .corbieMono()
                .foregroundStyle(palette.text2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
                .foregroundStyle(palette.text)
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
    let pot = PlanDTO(
        id: UUID(),
        title: "The pot",
        type: .other,
        currency: "USD",
        savedAmount: 400,
        addedAmount: 1240,
        isOpenEnded: true,
        createdAt: Date().addingTimeInterval(-120 * 24 * 60 * 60),
        expenseCount: 6
    )
    return VStack(spacing: CorbieSpacing.m) {
        PlanSummaryCard(plan: plan, totals: PlanTotals(plan: plan))
        PlanSummaryCard(plan: pot, totals: PlanTotals(plan: pot))
    }
    .padding(CorbieSpacing.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CorbieTheme.sand.palette.bg)
}
#endif
