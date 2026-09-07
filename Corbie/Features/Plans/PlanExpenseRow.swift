import CorbieCore
import SwiftUI

struct PlanExpenseRow: View {
    @Environment(\.palette) private var palette

    let expense: PlanExpenseDTO
    let planCurrency: String
    let memberSlot: MemberColorSlot?
    let memberName: String

    var body: some View {
        Card {
            HStack(alignment: .top, spacing: CorbieSpacing.s) {
                MemberDot(slot: memberSlot, accessibilityLabel: memberName)
                    .padding(.top, CorbieSpacing.xxs)
                VStack(alignment: .leading, spacing: CorbieSpacing.xxs) {
                    HStack(alignment: .firstTextBaseline, spacing: CorbieSpacing.xs) {
                        Text(Money(amount: expense.amount, currency: expense.currency).formatted())
                            .corbieBody()
                            .fontWeight(.semibold)
                            .foregroundStyle(palette.text)
                        if expense.isConverted {
                            Text(Money(amount: expense.amountInPlanCurrency, currency: planCurrency).approximate())
                                .corbieMono()
                                .foregroundStyle(palette.text2)
                        }
                    }
                    if let note = expense.note, note.isEmpty == false {
                        Text(note)
                            .corbieCaption()
                            .foregroundStyle(palette.text2)
                    }
                    if let date = expense.date {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .corbieMono()
                            .foregroundStyle(palette.text2)
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
            memberSlot: MemberColorSlot.rose,
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
            memberSlot: MemberColorSlot.teal,
            memberName: "you"
        )
    }
    .padding(CorbieSpacing.l)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CorbieTheme.sand.palette.bg)
}
#endif
