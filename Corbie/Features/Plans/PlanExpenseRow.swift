import CorbieCore
import SwiftUI

struct PlanExpenseRow: View {
    let expense: PlanExpenseDTO
    let planCurrency: String
    let memberColor: Color
    let memberName: String

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: CorbieSpacing.s) {
                MemberDot(color: memberColor, accessibilityLabel: memberName)
                    .padding(.top, CorbieSpacing.xxs)
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: CorbieSpacing.xs) {
                        Text(Money(amount: expense.amount, currency: expense.currency).formatted())
                            .corbieBody()
                            .fontWeight(.semibold)
                            .foregroundStyle(CorbieColorPalette.text)
                        if expense.isConverted {
                            Text(Money(amount: expense.amountInPlanCurrency, currency: planCurrency).approximate())
                                .corbieMono()
                                .foregroundStyle(CorbieColorPalette.text2)
                        }
                    }
                    if let note = expense.note, note.isEmpty == false {
                        Text(note)
                            .corbieCaption()
                            .foregroundStyle(CorbieColorPalette.text2)
                    }
                    if let date = expense.date {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .corbieMono()
                            .foregroundStyle(CorbieColorPalette.text2)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
#Preview {
    VStack(spacing: CorbieSpacing.m) {
        PlanExpenseRow(
            expense: PlanExpenseDTO(
                id: UUID(),
                amount: 210,
                currency: "EUR",
                fxRateToPlanCurrency: 1.09,
                amountInPlanCurrency: 228.9,
                note: "deposit",
                date: Date()
            ),
            planCurrency: "USD",
            memberColor: MemberColorKey.p2.color,
            memberName: "Sofia"
        )
        PlanExpenseRow(
            expense: PlanExpenseDTO(
                id: UUID(),
                amount: 640,
                currency: "USD",
                amountInPlanCurrency: 640,
                note: "flights",
                date: Date()
            ),
            planCurrency: "USD",
            memberColor: MemberColorKey.p1.color,
            memberName: "you"
        )
    }
    .padding(CorbieSpacing.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CorbieColorPalette.bg)
}
#endif
