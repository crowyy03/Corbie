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
                if let steps = planStepsBadge(done: plan.doneStepCount, total: plan.stepCount) {
                    Text(steps)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                }
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

struct CompactPlanCard: View {
    static let width: CGFloat = 240

    let plan: TodayPlan
    let showsSteps: Bool
    let open: () -> Void

    private var amount: String {
        String(format: String(localized: "plans.card.progress"), plan.savedText, plan.targetText)
    }

    private var steps: String? {
        planStepsBadge(done: plan.doneStepCount, total: plan.stepCount)
    }

    var body: some View {
        Button(action: open) {
            Card(showsChromeGradient: true) {
                VStack(alignment: .leading, spacing: CorbieSpacing.s) {
                    HStack(alignment: .firstTextBaseline, spacing: CorbieSpacing.xs) {
                        Image(systemName: plan.type.systemImage)
                            .foregroundStyle(CorbieColorPalette.text2)
                            .accessibilityHidden(true)
                        Text(plan.title)
                            .corbieBody()
                            .fontWeight(.semibold)
                            .foregroundStyle(CorbieColorPalette.text)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2, reservesSpace: true)
                        Spacer(minLength: 0)
                    }
                    ProgressBar(
                        value: plan.progress,
                        accessibilityLabel: String(localized: "plans.card.progress.label"),
                        accessibilityValue: amount
                    )
                    Text(amount)
                        .corbieMono()
                        .foregroundStyle(CorbieColorPalette.text2)
                        .lineLimit(1)
                    if showsSteps {
                        Text(steps ?? "")
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.text2)
                            .lineLimit(1, reservesSpace: true)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: CompactPlanCard.width)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#if DEBUG
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
                addedAmount: 1900,
                startAt: Date(),
                endAt: Date().addingTimeInterval(14 * 24 * 60 * 60),
                stepCount: 7,
                doneStepCount: 3
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
                addedAmount: 4340
            )
        )
    }
    .padding(CorbieSpacing.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CorbieColorPalette.bg)
}
#endif
