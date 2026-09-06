import CorbieCore
import SwiftUI

struct GoalSummaryCard: View {
    let goal: GoalDTO
    let totals: GoalTotals

    var body: some View {
        Card(showsChromeGradient: true) {
            VStack(alignment: .leading, spacing: CorbieSpacing.m) {
                header
                ProgressBar(
                    value: totals.progress,
                    overspend: totals.overspendFraction,
                    accessibilityLabel: String(localized: "goals.card.progress.label"),
                    accessibilityValue: totals.savedOfTarget()
                )
                amounts
                if totals.isOverspent {
                    Text(overspendText)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.warn)
                }
                if let dates = goalDateRange(start: goal.startAt, end: goal.endAt) {
                    Text(dates)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: CorbieSpacing.xs) {
            Image(systemName: goal.type.systemImage)
                .foregroundStyle(CorbieColorPalette.text2)
                .accessibilityHidden(true)
            Text(GoalsCopy.text(goal.type.titleKey))
                .corbieMono()
                .foregroundStyle(CorbieColorPalette.text2)
            Spacer(minLength: CorbieSpacing.xs)
            if goal.status != .active {
                Text(GoalsCopy.text(goal.status.titleKey))
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
            }
        }
    }

    private var amounts: some View {
        HStack(alignment: .top, spacing: CorbieSpacing.s) {
            column(label: String(localized: "goals.detail.saved"), amount: totals.saved)
            column(label: String(localized: "goals.detail.added"), amount: totals.added)
            column(label: String(localized: "goals.detail.left"), amount: totals.left)
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
            format: GoalsCopy.text("goals.detail.overspend"),
            totals.money(totals.overspend).formatted()
        )
    }
}

#if DEBUG
#Preview {
    let goal = GoalDTO(
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
    return GoalSummaryCard(goal: goal, totals: GoalTotals(goal: goal))
        .padding(CorbieSpacing.l)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(CorbieColorPalette.bg)
}
#endif
