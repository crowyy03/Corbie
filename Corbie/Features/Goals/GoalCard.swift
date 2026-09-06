import CorbieCore
import SwiftUI

struct GoalCard: View {
    let goal: GoalDTO

    private var totals: GoalTotals { GoalTotals(goal: goal) }

    var body: some View {
        Card(showsChromeGradient: goal.status == .active) {
            VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                header
                ProgressBar(
                    value: totals.progress,
                    overspend: totals.overspendFraction,
                    accessibilityLabel: String(localized: "goals.card.progress.label"),
                    accessibilityValue: totals.savedOfTarget()
                )
                footer
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: CorbieSpacing.xs) {
            Image(systemName: goal.type.systemImage)
                .foregroundStyle(CorbieColorPalette.text2)
                .accessibilityHidden(true)
            Text(goal.title)
                .corbieBody()
                .fontWeight(.semibold)
                .foregroundStyle(CorbieColorPalette.text)
                .lineLimit(2)
            Spacer(minLength: CorbieSpacing.xs)
            if goal.status == .completed {
                Text(GoalsCopy.text(GoalStatus.completed.titleKey))
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
            if let dates = goalDateRange(start: goal.startAt, end: goal.endAt) {
                Text(dates)
                    .corbieMono()
                    .foregroundStyle(CorbieColorPalette.text2)
                    .lineLimit(1)
            }
        }
    }
}

#if DEBUG
#Preview {
    VStack(spacing: CorbieSpacing.m) {
        GoalCard(
            goal: GoalDTO(
                id: UUID(),
                title: "Lisbon in October",
                type: .trip,
                targetAmount: 5000,
                currency: "USD",
                savedAmount: 2400,
                addedAmount: 1900,
                startAt: Date(),
                endAt: Date().addingTimeInterval(14 * 24 * 60 * 60)
            )
        )
        GoalCard(
            goal: GoalDTO(
                id: UUID(),
                title: "Kitchen",
                type: .renovation,
                targetAmount: 4000,
                currency: "USD",
                savedAmount: 4000,
                addedAmount: 4340
            )
        )
    }
    .padding(CorbieSpacing.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CorbieColorPalette.bg)
}
#endif
